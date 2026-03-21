import 'dart:io';

import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/expenses/domain/utils/split_calculator.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/utils/resolve_display_name.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:app/features/expenses/presentation/widgets/icon_picker_dialog.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.groupId,
    this.expenseId,
    this.templateExpense,
  });

  final String groupId;
  final String? expenseId;
  /// When set, pre-fills the form as a copy of this expense (id cleared, date = today).
  final ExpenseEntity? templateExpense;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  // Tasks 3.1: hidden TextField + focus node for amount
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  String _category = 'food';
  DateTime _expenseDate = DateTime.now();
  String? _paidBy;
  Set<String> _selectedMemberIds = {};
  bool _isSubmitting = false;
  bool _isLoaded = false;

  SplitType _splitType = SplitType.equal;
  String? _selectedCurrency;
  final Map<String, TextEditingController> _ratioControllers = {};
  final Map<String, TextEditingController> _fixedAmountControllers = {};
  final Map<String, FocusNode> _fixedAmountFocusNodes = {};

  // Attachments
  final List<File> _newAttachments = [];
  List<String> _existingAttachmentUrls = [];
  final List<String> _removedAttachmentUrls = [];
  final _imagePicker = ImagePicker();

  // Itemized split
  final List<_ItemEntry> _itemEntries = [];

  // Tasks 6.5 & 7.1: UI expansion state
  bool _splitTypeExpanded = false;
  bool _moreOptionsExpanded = false;

  // Available currencies are built dynamically in the build method
  // from the group base currency + currencies with exchange rates set.

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    for (final c in _ratioControllers.values) {
      c.dispose();
    }
    for (final c in _fixedAmountControllers.values) {
      c.dispose();
    }
    for (final n in _fixedAmountFocusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(List<GroupMemberEntity> members) {
    for (final member in members) {
      _ratioControllers.putIfAbsent(
        member.userId,
        () => TextEditingController(text: '1'),
      );
      _fixedAmountControllers.putIfAbsent(
        member.userId,
        () => TextEditingController(),
      );
      _fixedAmountFocusNodes.putIfAbsent(member.userId, () {
        final node = FocusNode();
        node.addListener(() {
          if (!node.hasFocus) _autoFillLastFixedAmount();
        });
        return node;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final exchangeRatesAsync = ref.watch(groupExchangeRatesProvider(widget.groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    final isOnline = ref.watch(isOnlineProvider);

    // Load existing expense data in edit mode
    if (widget.isEditing && !_isLoaded) {
      // Use live provider (backed by cached expensesProvider) to work offline.
      final liveKey = (groupId: widget.groupId, expenseId: widget.expenseId!);
      final expenseAsync = ref.watch(expenseDetailLiveProvider(liveKey));
      return Scaffold(
        appBar: AppBar(title: const Text('編輯消費')),
        body: expenseAsync.when(
          loading: () => const AppLoadingWidget(),
          error: (error, _) => AppErrorWidget(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(expenseDetailProvider(widget.expenseId!)),
          ),
          data: (expense) {
            if (!_isLoaded) {
              _amountController.text = expense.amount.toStringAsFixed(
                expense.amount.truncateToDouble() == expense.amount ? 0 : 2,
              );
              _descriptionController.text = expense.description;
              _noteController.text = expense.note ?? '';
              _category = expense.category;
              _expenseDate = expense.expenseDate;
              _paidBy = expense.paidBy;
              _selectedMemberIds = expense.splits.map((s) => s.userId).toSet();
              if (expense.splits.isNotEmpty) {
                _splitType = expense.splits.first.splitType;
              }
              _existingAttachmentUrls = List.of(expense.attachmentUrls);
              // Task 7.2: auto-expand more options if data exists
              _moreOptionsExpanded = (expense.note != null && expense.note!.isNotEmpty) ||
                  expense.attachmentUrls.isNotEmpty;
              _isLoaded = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() {}),
              );
            }
            return const AppLoadingWidget();
          },
        ),
      );
    }

    // Block editing while offline — edits require network.
    if (widget.isEditing && !isOnline) {
      return Scaffold(
        appBar: AppBar(title: const Text('編輯消費')),
        body: Column(
          children: [
            const OfflineBanner(),
            const Expanded(
              child: Center(child: Text('離線時無法編輯消費，請恢復網路後再試')),
            ),
          ],
        ),
      );
    }

    // 6.2: Block access for archived groups
    final isArchived = groupAsync.valueOrNull?.isArchived ?? false;
    if (isArchived) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? '編輯消費' : '新增消費')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.archive_outlined, size: 48),
                SizedBox(height: 16),
                Text(
                  '此群組已封存，無法新增或編輯消費',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '編輯消費' : '新增消費')),
      body: membersAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(groupMembersProvider(widget.groupId)),
        ),
        data: (members) {
          // Pre-fill from template (duplicate mode, first load only)
          if (widget.templateExpense != null && !_isLoaded) {
            final t = widget.templateExpense!;
            _amountController.text = t.amount.toStringAsFixed(
              t.amount.truncateToDouble() == t.amount ? 0 : 2,
            );
            _descriptionController.text = t.description;
            _noteController.text = t.note ?? '';
            _category = t.category;
            _expenseDate = DateTime.now();
            _paidBy = t.paidBy;
            _selectedCurrency = t.currency;
            final validSplitIds = t.splits
                .map((s) => s.userId)
                .where((id) => members.any((m) => m.userId == id))
                .toSet();
            _selectedMemberIds = validSplitIds.isNotEmpty
                ? validSplitIds
                : members.map((m) => m.userId).toSet();
            // Degrade itemized to fixedAmount (items not preserved in entity)
            if (t.splits.isNotEmpty) {
              _splitType = t.splits.first.splitType == SplitType.itemized
                  ? SplitType.fixedAmount
                  : t.splits.first.splitType;
            }
            _isLoaded = true;
          }

          // Initialize defaults
          if (_paidBy == null && currentUser != null) {
            _paidBy = currentUser.id;
          }
          if (_selectedMemberIds.isEmpty) {
            _selectedMemberIds = members.map((m) => m.userId).toSet();
          }
          _ensureControllers(members);

          // After controllers are ready, pre-fill fixedAmount values from template
          if (widget.templateExpense != null &&
              _splitType == SplitType.fixedAmount) {
            for (final split in widget.templateExpense!.splits) {
              _fixedAmountControllers[split.userId]?.text =
                  split.amount.toStringAsFixed(
                split.amount.truncateToDouble() == split.amount ? 0 : 2,
              );
            }
          }

          final groupCurrency =
              groupAsync.valueOrNull?.currency ?? AppConstants.defaultCurrency;
          final exchangeRateCurrencies = exchangeRatesAsync.valueOrNull
                  ?.map((r) => r.currency)
                  .toList() ??
              [];
          final availableCurrencies = [
            groupCurrency,
            ...exchangeRateCurrencies,
          ];
          _selectedCurrency ??= groupCurrency;
          // Reset to group currency if the previously selected currency
          // no longer has an exchange rate configured.
          if (!availableCurrencies.contains(_selectedCurrency)) {
            _selectedCurrency = groupCurrency;
          }

          return _buildLayout(
            context,
            members,
            _selectedCurrency!,
            availableCurrencies,
          );
        },
      ),
    );
  }

  // Task 8.3: Top-level Column layout — amount fixed top, ListView in middle, button fixed bottom
  Widget _buildLayout(
    BuildContext context,
    List<GroupMemberEntity> members,
    String currency,
    List<String> availableCurrencies,
  ) {
    final customCategoriesAsync = ref.watch(groupCategoriesProvider(widget.groupId));
    final customCategories = customCategoriesAsync.valueOrNull ?? [];
    final amount = double.tryParse(_amountController.text) ?? 0;
    final canSubmit = amount > 0 && _descriptionController.text.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Column(
      children: [
        const OfflineBanner(),
        // [A] Amount section — fixed at top
        _buildAmountSection(context, currency, availableCurrencies),

        // [B] Scrollable form body
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const SizedBox(height: 16),

              // [B1] Description + Category
              _buildDescriptionCategoryCard(context, customCategories),
              const SizedBox(height: 12),

              // [B2] Paid by
              _buildPaidByCard(context, members),
              const SizedBox(height: 12),

              // [B3] Split
              _buildSplitCard(context, members, amount),
              const SizedBox(height: 12),

              // [B4] More options (date, note, attachments)
              _buildMoreOptionsCard(context),
            ],
          ),
        ),

        // [C] Fixed bottom submit button
        _buildSubmitButton(context, currency, canSubmit),
      ],
    ));
  }

  // ─── [A] Amount Section ─────────────────────────────────────────────────

  Widget _buildAmountSection(
    BuildContext context,
    String currency,
    List<String> availableCurrencies,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _amountFocusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currency chip — tappable to change currency
            GestureDetector(
              onTap: () => _showCurrencyPicker(context, availableCurrencies),
              child: Container(
                padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCurrency ?? currency,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Amount input — visible TextField so the cursor tracks naturally
            TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_AmountInputFormatter()],
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                color: colorScheme.onSurface,
              ),
              cursorColor: colorScheme.primary,
              cursorHeight: 44,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ),

            // Thin divider line like a calculator screen
            Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
              thickness: 0.5,
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, List<String> availableCurrencies) {
    if (availableCurrencies.length <= 1) return;
    showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableCurrencies.map((c) => ListTile(
            title: Text(c),
            trailing: _selectedCurrency == c
                ? Icon(Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary)
                : null,
            onTap: () {
              setState(() => _selectedCurrency = c);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  // ─── [B1] Description + Category Card ───────────────────────────────────

  Widget _buildDescriptionCategoryCard(
    BuildContext context,
    List<dynamic> customCategories,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description — borderless, fills full width
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: '消費名稱（必填）',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),

          // Tasks 4.2–4.4: Horizontal tile category picker
          const SizedBox(height: 10),
          CategoryPicker(
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
            customCategories: customCategories
                .cast(),
            onAddCategory: () => _showAddCategoryDialog(context),
            onDeleteCategory: (id) => _deleteCategory(id),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ─── [B2] Paid By Card ───────────────────────────────────────────────────

  // Tasks 5.1–5.3: Avatar chip single-select for payer
  Widget _buildPaidByCard(BuildContext context, List<GroupMemberEntity> members) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(context, '誰付的錢'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((m) {
                final isSelected = _paidBy == m.userId;
                return _MemberChip(
                  name: resolveDisplayName(members, m),
                  isSelected: isSelected,
                  selectionMode: _ChipSelectionMode.single,
                  onTap: () => setState(() => _paidBy = m.userId),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── [B3] Split Card ─────────────────────────────────────────────────────

  Widget _buildSplitCard(
    BuildContext context,
    List<GroupMemberEntity> members,
    double amount,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task 6.1: Member chips multi-select
            _sectionLabel(context, '分攤成員'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((m) {
                final isSelected = _selectedMemberIds.contains(m.userId);
                return _MemberChip(
                  name: resolveDisplayName(members, m),
                  isSelected: isSelected,
                  selectionMode: _ChipSelectionMode.multi,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        // Task 6.3: min 1 person
                        if (_selectedMemberIds.length > 1) {
                          _selectedMemberIds.remove(m.userId);
                        }
                      } else {
                        _selectedMemberIds.add(m.userId);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            // Task 6.4: Inline split summary
            const SizedBox(height: 12),
            _buildSplitSummaryText(context, amount),

            const SizedBox(height: 8),

            // Tasks 6.5–6.8: ExpansionTile for split type
            _buildSplitTypeExpansion(context, members, amount),
          ],
        ),
      ),
    );
  }

  // Task 6.4: Real-time split summary
  Widget _buildSplitSummaryText(BuildContext context, double amount) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = _selectedMemberIds.length;
    String summary;

    switch (_splitType) {
      case SplitType.equal:
        if (amount > 0 && count > 0) {
          final perPerson = SplitCalculator.calculateEqualSplits(amount, count);
          final perPersonAmt = perPerson.isNotEmpty ? perPerson.first : 0.0;
          summary = '平均分給 $count 人，每人 ${_selectedCurrency} ${perPersonAmt.toStringAsFixed(2)}';
        } else {
          summary = '平均分給 $count 人';
        }
      case SplitType.customRatio:
        final ratioStr = _selectedMemberIds.map((id) {
          return _ratioControllers[id]?.text ?? '1';
        }).join(':');
        summary = '依自訂比例分配 ($ratioStr)';
      case SplitType.fixedAmount:
        summary = '指定各人金額';
      case SplitType.itemized:
        summary = '項目拆分（共 ${_itemEntries.length} 個品項）';
    }

    return Text(
      summary,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
    );
  }

  // Task 6.6: Header subtitle shows current split mode summary
  String _splitTypeHeaderSubtitle() {
    switch (_splitType) {
      case SplitType.equal:
        return '均分';
      case SplitType.customRatio:
        final ratioStr = _selectedMemberIds.map((id) {
          return _ratioControllers[id]?.text ?? '1';
        }).join(':');
        return '自訂比例 ($ratioStr)';
      case SplitType.fixedAmount:
        return '指定金額';
      case SplitType.itemized:
        return '項目拆分';
    }
  }

  // Tasks 6.5–6.8: Split type expansion tile
  Widget _buildSplitTypeExpansion(
    BuildContext context,
    List<GroupMemberEntity> members,
    double amount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      // Remove ExpansionTile's default divider
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: _splitTypeExpanded,
        onExpansionChanged: (v) => setState(() => _splitTypeExpanded = v),
        title: Text(
          '分帳方式',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        subtitle: Text(
          _splitTypeHeaderSubtitle(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        children: [
          const SizedBox(height: 4),

          // ── 分帳方式選擇器（SegmentedButton）────────────────────────────
          SegmentedButton<SplitType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: SplitType.equal, label: Text('均分')),
              ButtonSegment(value: SplitType.customRatio, label: Text('比例')),
              ButtonSegment(value: SplitType.fixedAmount, label: Text('金額')),
              ButtonSegment(value: SplitType.itemized, label: Text('項目')),
            ],
            selected: {_splitType},
            onSelectionChanged: (set) =>
                setState(() => _splitType = set.first),
          ),

          const SizedBox(height: 16),

          // ── 各分帳方式內容區 ─────────────────────────────────────────────
          if (_splitType == SplitType.equal) ...[
            ..._buildEqualSplitDisplay(context, members, amount),
          ],
          if (_splitType == SplitType.customRatio) ...[
            ..._buildRatioInputs(context, members, amount),
          ],
          if (_splitType == SplitType.fixedAmount) ...[
            ..._buildFixedAmountInputs(context, members, amount),
          ],
          if (_splitType == SplitType.itemized) ...[
            ..._buildItemizedList(members),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _itemEntries.add(_ItemEntry(
                      nameController: TextEditingController(),
                      amountController: TextEditingController(),
                      sharedByUserIds:
                          members.map((m) => m.userId).toSet(),
                    ));
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新增品項'),
              ),
            ),
            if (amount > 0) _buildItemizedHint(amount),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── [B4] More Options Card ──────────────────────────────────────────────

  Widget _buildMoreOptionsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _moreOptionsExpanded,
          onExpansionChanged: (v) => setState(() => _moreOptionsExpanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '更多選項',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          children: [
            // Task 7.3: Date moved here
            _buildDateTile(context),

            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // Task 7.4: Note moved here
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: '備註（選填）',
                prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              maxLines: 2,
            ),

            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // Task 7.5: Attachments moved here
            const SizedBox(height: 12),
            _buildAttachmentSection(context),
          ],
        ),
      ),
    );
  }

  // Task 7.3: Date tile
  Widget _buildDateTile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _expenseDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) setState(() => _expenseDate = picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              '日期',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              DateFormat('yyyy/MM/dd').format(_expenseDate),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ─── [C] Fixed Submit Button ─────────────────────────────────────────────

  // Task 8.1–8.2: Fixed bottom FilledButton
  Widget _buildSubmitButton(BuildContext context, String currency, bool canSubmit) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: (canSubmit && !_isSubmitting)
              ? () => _handleSubmit(currency)
              : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.isEditing ? '儲存變更' : '新增消費',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ──────────────────────────────────────────────────────

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  // ─── Split Input Helpers ──────────────────────────────────────────────────

  /// 均分：唯讀顯示每人分攤金額，版面與 ratio/fixed 一致
  List<Widget> _buildEqualSplitDisplay(
    BuildContext context,
    List<GroupMemberEntity> members,
    double amount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = _selectedMemberIds.length;
    final splits = amount > 0 && count > 0
        ? SplitCalculator.calculateEqualSplits(amount, count)
        : <double>[];

    final selectedMembers =
        members.where((m) => _selectedMemberIds.contains(m.userId)).toList();

    return selectedMembers.asMap().entries.map((entry) {
      final member = entry.value;
      final splitAmt =
          entry.key < splits.length ? splits[entry.key] : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                resolveDisplayName(members, member),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              amount > 0 ? '${_selectedCurrency} ${splitAmt.toStringAsFixed(2)}' : '',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildRatioInputs(
    BuildContext context,
    List<GroupMemberEntity> members,
    double amount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
    );

    final ratios = <String, int>{};
    for (final id in _selectedMemberIds) {
      ratios[id] = int.tryParse(_ratioControllers[id]?.text ?? '1') ?? 1;
    }
    final ratioSplits = amount > 0
        ? SplitCalculator.calculateRatioSplits(amount, ratios)
        : <String, double>{};

    return members.map((member) {
      final isSelected = _selectedMemberIds.contains(member.userId);
      if (!isSelected) return const SizedBox.shrink();
      final splitAmount = ratioSplits[member.userId] ?? 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(resolveDisplayName(members, member), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _ratioControllers[member.userId],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: Text(
                amount > 0 ? '${_selectedCurrency} ${splitAmount.toStringAsFixed(2)}' : '',
                textAlign: TextAlign.right,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildFixedAmountInputs(
    BuildContext context,
    List<GroupMemberEntity> members,
    double amount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
    );

    return [
      ...members.map((member) {
        final isSelected = _selectedMemberIds.contains(member.userId);
        if (!isSelected) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: Text(resolveDisplayName(members, member), maxLines: 1, overflow: TextOverflow.ellipsis)),
              SizedBox(
                width: 136,
                child: TextField(
                  controller: _fixedAmountControllers[member.userId],
                  focusNode: _fixedAmountFocusNodes[member.userId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    prefixText: '${_selectedCurrency} ',
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        );
      }),
      if (amount > 0) _buildFixedAmountHint(amount),
    ];
  }

  Widget _buildFixedAmountHint(double amount) {
    final amounts = _getFixedAmountsMap();
    final diff = SplitCalculator.fixedAmountDifference(amount, amounts);

    if (diff.abs() < 0.01) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '金額分配正確',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        diff > 0
            ? '還差 ${_selectedCurrency} ${diff.toStringAsFixed(2)} 未分配'
            : '超出 ${_selectedCurrency} ${diff.abs().toStringAsFixed(2)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      ),
    );
  }

  void _autoFillLastFixedAmount() {
    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    if (totalAmount <= 0) return;

    final emptyIds = _selectedMemberIds
        .where((id) => (_fixedAmountControllers[id]?.text ?? '').isEmpty)
        .toList();

    if (emptyIds.length != 1) return;

    // Don't overwrite while the user is actively editing that field
    if (_fixedAmountFocusNodes[emptyIds.first]?.hasFocus == true) return;

    double filled = 0;
    for (final id in _selectedMemberIds) {
      if (id == emptyIds.first) continue;
      filled += double.tryParse(_fixedAmountControllers[id]?.text ?? '') ?? 0;
    }

    final remaining = totalAmount - filled;
    if (remaining <= 0) return;

    _fixedAmountControllers[emptyIds.first]?.text = remaining % 1 == 0
        ? remaining.toStringAsFixed(0)
        : remaining.toStringAsFixed(2);
    setState(() {});
  }

  Map<String, double> _getFixedAmountsMap() {
    final amounts = <String, double>{};
    for (final id in _selectedMemberIds) {
      amounts[id] = double.tryParse(_fixedAmountControllers[id]?.text ?? '') ?? 0;
    }
    return amounts;
  }

  List<Widget> _buildItemizedList(List<GroupMemberEntity> members) {
    return _itemEntries.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: item.nameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: '品項名稱',
                        labelStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: item.amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: '金額',
                        labelStyle: const TextStyle(fontSize: 12),
                        prefixText: '${_selectedCurrency} ',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    onPressed: () {
                      setState(() {
                        _itemEntries[idx].nameController.dispose();
                        _itemEntries[idx].amountController.dispose();
                        _itemEntries.removeAt(idx);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '分攤者',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: members.map((m) {
                  final selected = item.sharedByUserIds.contains(m.userId);
                  return FilterChip(
                    label: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          item.sharedByUserIds.add(m.userId);
                        } else if (item.sharedByUserIds.length > 1) {
                          item.sharedByUserIds.remove(m.userId);
                        }
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildItemizedHint(double totalAmount) {
    double itemsTotal = 0;
    for (final item in _itemEntries) {
      itemsTotal += double.tryParse(item.amountController.text) ?? 0;
    }
    final diff = totalAmount - itemsTotal;

    if (diff.abs() < 0.01) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '品項金額合計正確',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 13,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        diff > 0
            ? '還差 ${_selectedCurrency} ${diff.toStringAsFixed(2)} 未分配'
            : '超出 ${_selectedCurrency} ${diff.abs().toStringAsFixed(2)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      ),
    );
  }

  // ─── Attachment Section ──────────────────────────────────────────────────

  Widget _buildAttachmentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.attach_file_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '收據 / 照片',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._existingAttachmentUrls.map((url) => _AttachmentThumbnail(
                  imageProvider: NetworkImage(url),
                  onRemove: () {
                    setState(() {
                      _existingAttachmentUrls.remove(url);
                      _removedAttachmentUrls.add(url);
                    });
                  },
                )),
            ..._newAttachments.map((file) => _AttachmentThumbnail(
                  imageProvider: FileImage(file),
                  onRemove: () => setState(() => _newAttachments.remove(file)),
                )),
            InkWell(
              onTap: _pickAttachment,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('從相簿選取'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _newAttachments.add(File(picked.path)));
    }
  }

  // ─── Category Dialogs ────────────────────────────────────────────────────

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );

    if (result != null && mounted) {
      final ds = ref.read(supabaseExpenseDataSourceProvider);
      await ds.createGroupCategory(
        groupId: widget.groupId,
        name: result['name']!,
        iconName: result['icon']!,
      );
      ref.invalidate(groupCategoriesProvider(widget.groupId));
      setState(() => _category = result['name']!);
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    final ds = ref.read(supabaseExpenseDataSourceProvider);
    await ds.deleteGroupCategory(categoryId);
    ref.invalidate(groupCategoriesProvider(widget.groupId));
    final customCategories =
        ref.read(groupCategoriesProvider(widget.groupId)).valueOrNull ?? [];
    final stillExists = customCategories.any((c) => c.name == _category);
    if (!stillExists && !builtInCategoryLabels.containsKey(_category)) {
      setState(() => _category = 'food');
    }
  }

  // ─── Submit Logic (unchanged) ────────────────────────────────────────────

  List<Map<String, dynamic>> _buildSplitsPayload(double amount) {
    if (_splitType == SplitType.itemized) {
      return _buildItemizedSplitsPayload();
    }

    final memberIds = _selectedMemberIds.toList();

    switch (_splitType) {
      case SplitType.equal:
        final splitAmounts = SplitCalculator.calculateEqualSplits(
          amount,
          memberIds.length,
        );
        return List.generate(
          memberIds.length,
          (i) => {
            'user_id': memberIds[i],
            'amount': splitAmounts[i],
            'split_type': 'equal',
          },
        );

      case SplitType.customRatio:
        final ratios = <String, int>{};
        for (final id in memberIds) {
          ratios[id] = int.tryParse(_ratioControllers[id]?.text ?? '1') ?? 1;
        }
        final ratioSplits = SplitCalculator.calculateRatioSplits(amount, ratios);
        return memberIds
            .map((id) => {
                  'user_id': id,
                  'amount': ratioSplits[id] ?? 0.0,
                  'split_type': 'custom_ratio',
                })
            .toList();

      case SplitType.fixedAmount:
        final amounts = _getFixedAmountsMap();
        return memberIds
            .map((id) => {
                  'user_id': id,
                  'amount': amounts[id] ?? 0.0,
                  'split_type': 'fixed_amount',
                })
            .toList();

      case SplitType.itemized:
        return _buildItemizedSplitsPayload();
    }
  }

  List<Map<String, dynamic>> _buildItemizedSplitsPayload() {
    final perUser = <String, double>{};
    for (final item in _itemEntries) {
      final itemAmount = double.tryParse(item.amountController.text) ?? 0;
      if (itemAmount <= 0 || item.sharedByUserIds.isEmpty) continue;
      final share = itemAmount / item.sharedByUserIds.length;
      for (final userId in item.sharedByUserIds) {
        perUser[userId] = (perUser[userId] ?? 0) + share;
      }
    }

    return perUser.entries
        .map((e) => {
              'user_id': e.key,
              'amount': double.parse(e.value.toStringAsFixed(2)),
              'split_type': 'itemized',
            })
        .toList();
  }

  Future<List<String>> _processAttachments(String expenseId) async {
    final ds = ref.read(supabaseExpenseDataSourceProvider);

    for (final url in _removedAttachmentUrls) {
      try {
        await ds.removeAttachment(url);
      } catch (_) {}
    }

    final newUrls = <String>[];
    for (final file in _newAttachments) {
      final url = await ds.uploadAttachment(
        expenseId: expenseId,
        filePath: file.path,
      );
      newUrls.add(url);
    }

    return [..._existingAttachmentUrls, ...newUrls];
  }

  Future<void> _handleSubmit(String currency) async {
    if (_splitType != SplitType.itemized && _selectedMemberIds.isEmpty) return;

    final amount = double.parse(_amountController.text);
    final description = _descriptionController.text.trim();
    if (amount <= 0 || description.isEmpty) return;

    if (_splitType == SplitType.fixedAmount) {
      final amounts = _getFixedAmountsMap();
      if (!SplitCalculator.validateFixedAmounts(amount, amounts)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('指定金額加總必須等於總金額')),
        );
        return;
      }
    }

    if (_splitType == SplitType.itemized) {
      if (_itemEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請至少新增一個品項')),
        );
        return;
      }
      double itemsTotal = 0;
      for (final item in _itemEntries) {
        itemsTotal += double.tryParse(item.amountController.text) ?? 0;
      }
      if ((amount - itemsTotal).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('品項金額合計必須等於總金額')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final hasAttachmentChanges =
        _newAttachments.isNotEmpty || _removedAttachmentUrls.isNotEmpty;

    if (widget.isEditing) {
      final splits = _buildSplitsPayload(amount);
      final updateExpense = ref.read(updateExpenseUseCaseProvider);
      final result = await updateExpense(
        expenseId: widget.expenseId!,
        paidBy: _paidBy!,
        amount: amount,
        category: _category,
        description: description,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        expenseDate: _expenseDate,
        splits: splits,
      );

      if (!mounted) return;

      await result.fold(
        (failure) async {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (_) async {
          if (hasAttachmentChanges) {
            try {
              final urls = await _processAttachments(widget.expenseId!);
              final ds = ref.read(supabaseExpenseDataSourceProvider);
              await ds.updateAttachmentUrls(
                expenseId: widget.expenseId!,
                urls: urls,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('附件上傳失敗：$e')),
                );
              }
            }
          }
          setState(() => _isSubmitting = false);
          ref.invalidate(expensesProvider(widget.groupId));
          ref.invalidate(expenseDetailProvider(widget.expenseId!));
          ref.invalidate(balancesProvider(widget.groupId));
          if (mounted) context.pop();
        },
      );
    } else {
      final splits = _buildSplitsPayload(amount);
      final createExpense = ref.read(createExpenseUseCaseProvider);
      final result = await createExpense(
        groupId: widget.groupId,
        paidBy: _paidBy!,
        amount: amount,
        currency: currency,
        category: _category,
        description: description,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        expenseDate: _expenseDate,
        splits: splits,
      );

      if (!mounted) return;

      await result.fold(
        (failure) async {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (expenseId) async {
          final isOnline = ref.read(isOnlineProvider);
          if (!isOnline) {
            // Saved to pending queue — refresh list so pending item shows,
            // then show offline message and pop.
            ref.invalidate(expensesProvider(widget.groupId));
            ref.invalidate(pendingCountProvider);
            setState(() => _isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('已排程，連線後自動同步'),
                    ],
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
              context.pop();
            }
            return;
          }
          if (hasAttachmentChanges) {
            try {
              final urls = await _processAttachments(expenseId);
              final ds = ref.read(supabaseExpenseDataSourceProvider);
              await ds.updateAttachmentUrls(
                expenseId: expenseId,
                urls: urls,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('附件上傳失敗：$e')),
                );
              }
            }
          }
          setState(() => _isSubmitting = false);
          ref.invalidate(expensesProvider(widget.groupId));
          ref.invalidate(balancesProvider(widget.groupId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('消費已新增'),
                  ],
                ),
                duration: Duration(milliseconds: 1500),
              ),
            );
            context.pop();
          }
        },
      );
    }
  }
}

// ─── Amount Input Formatter ──────────────────────────────────────────────────

// Task 3.3: Only digits + one decimal point, max 2 decimal places
class _AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Only digits and one dot
    final filtered = text.replaceAll(RegExp(r'[^0-9.]'), '');

    // Only one decimal point
    final dotIndex = filtered.indexOf('.');
    final cleaned = dotIndex == -1
        ? filtered
        : filtered.substring(0, dotIndex + 1) +
            filtered.substring(dotIndex + 1).replaceAll('.', '');

    // Max 2 decimal places
    final dotPos = cleaned.indexOf('.');
    final result = dotPos == -1
        ? cleaned
        : cleaned.length - dotPos - 1 > 2
            ? cleaned.substring(0, dotPos + 3)
            : cleaned;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ─── Member Chip Widget ──────────────────────────────────────────────────────

enum _ChipSelectionMode { single, multi }

// Tasks 5.1–5.3 / 6.1–6.3: Reusable avatar chip for payer & split members
class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.name,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final _ChipSelectionMode selectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSingle = selectionMode == _ChipSelectionMode.single;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isSingle ? colorScheme.surface : colorScheme.primary)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: isSelected && isSingle
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isSelected
                  ? (isSingle ? colorScheme.primary : Colors.white.withValues(alpha: 0.3))
                  : colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? (isSingle ? colorScheme.primary : Colors.white)
                      : colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected && isSingle) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 14, color: colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Data Classes (unchanged) ────────────────────────────────────────────────

class _ItemEntry {
  _ItemEntry({
    required this.nameController,
    required this.amountController,
    required this.sharedByUserIds,
  });

  final TextEditingController nameController;
  final TextEditingController amountController;
  final Set<String> sharedByUserIds;
}

class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({
    required this.imageProvider,
    required this.onRemove,
  });

  final ImageProvider imageProvider;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: imageProvider,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 12,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 新增自訂分類 Dialog ───────────────────────────────────────────────────────
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  late final TextEditingController _nameController;
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final icon = await showDialog<String>(
      context: context,
      builder: (_) => const IconPickerDialog(),
    );
    if (icon != null && mounted) {
      setState(() => _selectedIcon = icon);
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _selectedIcon != null) {
      Navigator.of(context).pop({'name': name, 'icon': _selectedIcon!});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增自訂分類'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '分類名稱'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('圖示：'),
              const SizedBox(width: 8),
              if (_selectedIcon != null)
                Icon(resolveIcon(_selectedIcon!), size: 24),
              const Spacer(),
              TextButton(
                onPressed: _pickIcon,
                child: Text(_selectedIcon == null ? '選擇圖示' : '更換'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('新增'),
        ),
      ],
    );
  }
}
