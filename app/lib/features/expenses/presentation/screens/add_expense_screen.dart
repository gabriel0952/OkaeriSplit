import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/expenses/domain/utils/split_calculator.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/utils/resolve_display_name.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/expense_item_entity.dart';
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
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/presentation/screens/receipt_scan_result_screen.dart';
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
  final _formScrollController = ScrollController();
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
  double _amountCollapseProgress = 0;

  static const double _amountCollapseOffset = 72;

  // Available currencies are built dynamically in the build method
  // from the group base currency + currencies with exchange rates set.

  @override
  void initState() {
    super.initState();
    _formScrollController.addListener(_handleScroll);
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _formScrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _amountController.removeListener(_handleAmountChanged);
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
    _disposeItemEntries();
    super.dispose();
  }

  void _handleScroll() {
    if (!_formScrollController.hasClients) return;

    final nextProgress = (_formScrollController.offset / _amountCollapseOffset)
        .clamp(0.0, 1.0);
    if ((nextProgress - _amountCollapseProgress).abs() < 0.02) return;

    setState(() {
      _amountCollapseProgress = nextProgress;
    });
  }

  void _handleAmountChanged() {
    if (!mounted) return;
    setState(() {});
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
    final exchangeRatesAsync = ref.watch(
      groupExchangeRatesProvider(widget.groupId),
    );
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
              if (expense.splits.isNotEmpty) {
                _splitType = expense.splits.first.splitType;
              }
              _hydrateItemEntries(expense.items);
              final splitMemberIds = expense.splits
                  .map((s) => s.userId)
                  .toSet();
              final itemizedMemberIds = _collectSelectedMemberIdsFromItems();
              _selectedMemberIds = _splitType == SplitType.itemized
                  ? (itemizedMemberIds.isNotEmpty
                        ? itemizedMemberIds
                        : splitMemberIds)
                  : splitMemberIds;
              _existingAttachmentUrls = List.of(expense.attachmentUrls);
              // Task 7.2: auto-expand more options if data exists
              _moreOptionsExpanded =
                  (expense.note != null && expense.note!.isNotEmpty) ||
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
            const Expanded(child: Center(child: Text('離線時無法編輯消費，請恢復網路後再試'))),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.archive_outlined, size: 48),
                SizedBox(height: 16),
                Text('此群組已封存，無法新增或編輯消費', textAlign: TextAlign.center),
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
            if (t.splits.isNotEmpty) {
              _splitType = t.splits.first.splitType;
            }
            if (t.items.isNotEmpty) {
              _hydrateItemEntries(
                t.items,
                validMemberIds: {for (final member in members) member.userId},
              );
            }
            final validSplitIds = t.splits
                .map((s) => s.userId)
                .where((id) => members.any((m) => m.userId == id))
                .toSet();
            final itemizedMemberIds = _collectSelectedMemberIdsFromItems();
            _selectedMemberIds = _splitType == SplitType.itemized
                ? (itemizedMemberIds.isNotEmpty
                      ? itemizedMemberIds
                      : members.map((m) => m.userId).toSet())
                : (validSplitIds.isNotEmpty
                      ? validSplitIds
                      : members.map((m) => m.userId).toSet());
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
          _normalizeItemizedAssignments(members);

          // After controllers are ready, pre-fill fixedAmount values from template
          if (widget.templateExpense != null &&
              _splitType == SplitType.fixedAmount) {
            for (final split in widget.templateExpense!.splits) {
              _fixedAmountControllers[split.userId]?.text = split.amount
                  .toStringAsFixed(
                    split.amount.truncateToDouble() == split.amount ? 0 : 2,
                  );
            }
          }

          final groupCurrency =
              groupAsync.valueOrNull?.currency ?? AppConstants.defaultCurrency;
          final exchangeRateCurrencies =
              exchangeRatesAsync.valueOrNull?.map((r) => r.currency).toList() ??
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
    final customCategoriesAsync = ref.watch(
      groupCategoriesProvider(widget.groupId),
    );
    final customCategories = customCategoriesAsync.valueOrNull ?? [];
    final amount = double.tryParse(_amountController.text) ?? 0;
    final canSubmit =
        amount > 0 && _descriptionController.text.trim().isNotEmpty;

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
              controller: _formScrollController,
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
      ),
    );
  }

  // ─── [A] Amount Section ─────────────────────────────────────────────────

  Widget _buildAmountSection(
    BuildContext context,
    String currency,
    List<String> availableCurrencies,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = Curves.easeOutCubic.transform(_amountCollapseProgress);
    final expandedOpacity = 1 - progress;
    final collapsedOpacity = Curves.easeInOut.transform(progress);

    return Container(
      color: colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        20,
        lerpDouble(12, 10, progress)!,
        20,
        lerpDouble(16, 10, progress)!,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCurrencyChip(context, currency, availableCurrencies),
              SizedBox(width: lerpDouble(0, 10, collapsedOpacity)),
              Expanded(
                child: IgnorePointer(
                  ignoring: collapsedOpacity < 0.2,
                  child: Opacity(
                    opacity: collapsedOpacity,
                    child: Transform.translate(
                      offset: Offset(0, lerpDouble(8, 0, collapsedOpacity)!),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _expandAmountEditor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _currentAmountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.4,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildReceiptScanChip(context),
            ],
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: lerpDouble(1, 0, progress)!.clamp(0.0, 1.0),
              child: Opacity(
                opacity: expandedOpacity,
                child: Transform.translate(
                  offset: Offset(0, lerpDouble(0, -12, progress)!),
                  child: _buildExpandedAmountContent(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedAmountContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _amountFocusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
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
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            height: 1,
            thickness: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(
    BuildContext context,
    String currency,
    List<String> availableCurrencies,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showCurrencyPicker(context, availableCurrencies),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
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
    );
  }

  Widget _buildReceiptScanChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _startReceiptScan,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 15,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '掃描收據',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _expandAmountEditor() async {
    if (_formScrollController.hasClients) {
      await _formScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    _amountFocusNode.requestFocus();
  }

  String get _currentAmountText => _amountController.text.trim().isEmpty
      ? '0'
      : _amountController.text.trim();

  void _showCurrencyPicker(
    BuildContext context,
    List<String> availableCurrencies,
  ) {
    if (availableCurrencies.length <= 1) return;
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _StandardSheetHandle(),
            const _StandardSheetHeader(title: '選擇幣別'),
            ...availableCurrencies.map(
              (c) => ListTile(
                title: Text(c),
                trailing: _selectedCurrency == c
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedCurrency = c);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
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
            customCategories: customCategories.cast(),
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
  Widget _buildPaidByCard(
    BuildContext context,
    List<GroupMemberEntity> members,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(context, '誰付的錢'),
            const SizedBox(height: 12),
            _buildMemberSelectorScroller(
              context,
              members: members,
              enableSmartHint: true,
              selectionMode: _ChipSelectionMode.single,
              isSelected: (member) => _paidBy == member.userId,
              onTap: (member) => setState(() => _paidBy = member.userId),
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
    final isItemizedMode = _splitType == SplitType.itemized;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task 6.1: Member chips multi-select
            _sectionLabel(context, '分攤成員'),
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: isItemizedMode,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isItemizedMode ? 0.45 : 1,
                child: _buildMemberSelectorScroller(
                  context,
                  members: members,
                  enableSmartHint: false,
                  selectionMode: _ChipSelectionMode.multi,
                  isSelected: (member) =>
                      _selectedMemberIds.contains(member.userId),
                  onTap: (member) {
                    final isSelected = _selectedMemberIds.contains(
                      member.userId,
                    );
                    setState(() {
                      if (isSelected) {
                        if (_selectedMemberIds.length > 1) {
                          _selectedMemberIds.remove(member.userId);
                        }
                      } else {
                        _selectedMemberIds.add(member.userId);
                      }
                    });
                  },
                ),
              ),
            ),
            if (isItemizedMode) ...[
              const SizedBox(height: 8),
              Text(
                '項目拆分時，分攤者會由下方每個品項各自控制。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],

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

  Widget _buildMemberSelectorScroller(
    BuildContext context, {
    required List<GroupMemberEntity> members,
    required bool enableSmartHint,
    required _ChipSelectionMode selectionMode,
    required bool Function(GroupMemberEntity member) isSelected,
    required void Function(GroupMemberEntity member) onTap,
  }) {
    if (members.length < 3) {
      return _buildMemberSelectorRow(
        context,
        allMembers: members,
        rowMembers: members,
        enableSmartHint: false,
        selectionMode: selectionMode,
        isSelected: isSelected,
        onTap: onTap,
      );
    }

    final splitIndex = (members.length / 2).ceil();
    final firstRowMembers = members.take(splitIndex).toList();
    final secondRowMembers = members.skip(splitIndex).toList();

    return Column(
      children: [
        _buildMemberSelectorRow(
          context,
          allMembers: members,
          rowMembers: firstRowMembers,
          enableSmartHint: enableSmartHint,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onTap: onTap,
        ),
        if (secondRowMembers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildMemberSelectorRow(
            context,
            allMembers: members,
            rowMembers: secondRowMembers,
            enableSmartHint: enableSmartHint,
            selectionMode: selectionMode,
            isSelected: isSelected,
            onTap: onTap,
          ),
        ],
      ],
    );
  }

  Widget _buildMemberSelectorRow(
    BuildContext context, {
    required List<GroupMemberEntity> allMembers,
    required List<GroupMemberEntity> rowMembers,
    required bool enableSmartHint,
    required _ChipSelectionMode selectionMode,
    required bool Function(GroupMemberEntity member) isSelected,
    required void Function(GroupMemberEntity member) onTap,
  }) {
    return SizedBox(
      height: 40,
      child: _ScrollableMemberSelectorRow(
        enableSmartHint: enableSmartHint,
        itemCount: rowMembers.length,
        itemBuilder: (context, index) {
          final member = rowMembers[index];
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 92),
            child: _MemberChip(
              name: resolveDisplayName(allMembers, member),
              isSelected: isSelected(member),
              selectionMode: selectionMode,
              onTap: () => onTap(member),
            ),
          );
        },
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
          summary =
              '平均分給 $count 人，每人 $_selectedCurrency ${perPersonAmt.toStringAsFixed(2)}';
        } else {
          summary = '平均分給 $count 人';
        }
      case SplitType.customRatio:
        final ratioStr = _selectedMemberIds
            .map((id) {
              return _ratioControllers[id]?.text ?? '1';
            })
            .join(':');
        summary = '依自訂比例分配 ($ratioStr)';
      case SplitType.fixedAmount:
        summary = '指定各人金額';
      case SplitType.itemized:
        summary = '項目拆分（共 ${_itemEntries.length} 個品項）';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Task 6.6: Header subtitle shows current split mode summary
  String _splitTypeHeaderSubtitle() {
    switch (_splitType) {
      case SplitType.equal:
        return '均分';
      case SplitType.customRatio:
        final ratioStr = _selectedMemberIds
            .map((id) {
              return _ratioControllers[id]?.text ?? '1';
            })
            .join(':');
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
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: _splitTypeExpanded,
        onExpansionChanged: (v) => setState(() => _splitTypeExpanded = v),
        title: Text(
          '分帳方式',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _splitTypeHeaderSubtitle(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        children: [
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              final List<_SplitModeOption> modes = [
                _SplitModeOption(
                  type: SplitType.equal,
                  icon: Icons.group_outlined,
                  title: '均分',
                  description: '自動平均分給已選成員',
                ),
                _SplitModeOption(
                  type: SplitType.customRatio,
                  icon: Icons.balance_outlined,
                  title: '比例',
                  description: '用比例控制各自分攤',
                ),
                _SplitModeOption(
                  type: SplitType.fixedAmount,
                  icon: Icons.payments_outlined,
                  title: '金額',
                  description: '直接輸入每個人的金額',
                ),
                _SplitModeOption(
                  type: SplitType.itemized,
                  icon: Icons.receipt_long_outlined,
                  title: '項目',
                  description: '逐項編輯品項與分攤者',
                ),
              ];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: modes
                    .map(
                      (mode) => SizedBox(
                        width: cardWidth,
                        child: _SplitModeCard(
                          option: mode,
                          isSelected: _splitType == mode.type,
                          onTap: () => setState(() => _splitType = mode.type),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 16),
          if (_splitType == SplitType.equal) ...[
            _buildSplitContentCard(
              context,
              title: '均分明細',
              child: Column(
                children: _buildEqualSplitDisplay(context, members, amount),
              ),
            ),
          ],
          if (_splitType == SplitType.customRatio) ...[
            _buildSplitContentCard(
              context,
              title: '比例設定',
              subtitle: '建議用較大的比例數字，方便快速調整。',
              child: Column(
                children: _buildRatioInputs(context, members, amount),
              ),
            ),
          ],
          if (_splitType == SplitType.fixedAmount) ...[
            _buildSplitContentCard(
              context,
              title: '金額設定',
              subtitle: '直接填入每位成員要負擔的金額。',
              child: Column(
                children: _buildFixedAmountInputs(context, members, amount),
              ),
            ),
          ],
          if (_splitType == SplitType.itemized) ...[
            _buildSplitContentCard(
              context,
              title: '項目拆分',
              subtitle: '每張品項卡都能獨立調整名稱、金額與分攤者。',
              child: Column(
                children: [
                  ..._buildItemizedList(members),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _itemEntries.add(
                            _ItemEntry(
                              nameController: TextEditingController(),
                              amountController: TextEditingController(),
                              sharedByUserIds: members
                                  .map((m) => m.userId)
                                  .toSet(),
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('新增品項'),
                    ),
                  ),
                  if (amount > 0) _buildItemizedHint(amount),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSplitContentCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
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
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '更多選項',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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
            Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text('日期', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              DateFormat('yyyy/MM/dd').format(_expenseDate),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ─── [C] Fixed Submit Button ─────────────────────────────────────────────

  // Task 8.1–8.2: Fixed bottom FilledButton
  Widget _buildSubmitButton(
    BuildContext context,
    String currency,
    bool canSubmit,
  ) {
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
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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

    final selectedMembers = members
        .where((m) => _selectedMemberIds.contains(m.userId))
        .toList();

    return selectedMembers.asMap().entries.map((entry) {
      final member = entry.value;
      final splitAmt = entry.key < splits.length ? splits[entry.key] : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  resolveDisplayName(members, member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                amount > 0
                    ? '$_selectedCurrency ${splitAmt.toStringAsFixed(2)}'
                    : '-',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolveDisplayName(members, member),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: TextField(
                      controller: _ratioControllers[member.userId],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: InputDecoration(
                        labelText: '比例',
                        isDense: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        amount > 0
                            ? '預計 $_selectedCurrency ${splitAmount.toStringAsFixed(2)}'
                            : '輸入比例後顯示',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
    );

    return [
      ...members.map((member) {
        final isSelected = _selectedMemberIds.contains(member.userId);
        if (!isSelected) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolveDisplayName(members, member),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fixedAmountControllers[member.userId],
                  focusNode: _fixedAmountFocusNodes[member.userId],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: InputDecoration(
                    labelText: '分攤金額',
                    prefixText: '$_selectedCurrency ',
                    isDense: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        );
      }),
      if (amount > 0) _buildFixedAmountHint(amount),
    ];
  }

  Widget _buildItemField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? prefixText,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      onChanged: onChanged,
    );
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
            ? '還差 $_selectedCurrency ${diff.toStringAsFixed(2)} 未分配'
            : '超出 $_selectedCurrency ${diff.abs().toStringAsFixed(2)}',
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
      amounts[id] =
          double.tryParse(_fixedAmountControllers[id]?.text ?? '') ?? 0;
    }
    return amounts;
  }

  List<Widget> _buildItemizedList(List<GroupMemberEntity> members) {
    return _itemEntries.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      final colorScheme = Theme.of(context).colorScheme;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '品項 ${idx + 1}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () {
                      setState(() {
                        _itemEntries[idx].nameController.dispose();
                        _itemEntries[idx].amountController.dispose();
                        _itemEntries.removeAt(idx);
                      });
                    },
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      backgroundColor: colorScheme.errorContainer.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildItemField(
                context,
                controller: item.nameController,
                label: '品項名稱',
              ),
              const SizedBox(height: 12),
              _buildItemField(
                context,
                controller: item.amountController,
                label: '金額',
                prefixText: '$_selectedCurrency ',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text(
                '分攤者',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildMemberSelectorScroller(
                context,
                members: members,
                enableSmartHint: false,
                selectionMode: _ChipSelectionMode.multi,
                isSelected: (member) =>
                    item.sharedByUserIds.contains(member.userId),
                onTap: (member) {
                  final selected = item.sharedByUserIds.contains(member.userId);
                  setState(() {
                    if (!selected) {
                      item.sharedByUserIds.add(member.userId);
                    } else if (item.sharedByUserIds.length > 1) {
                      item.sharedByUserIds.remove(member.userId);
                    }
                  });
                },
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
            ? '還差 $_selectedCurrency ${diff.toStringAsFixed(2)} 未分配'
            : '超出 $_selectedCurrency ${diff.abs().toStringAsFixed(2)}',
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
            Text('收據 / 照片', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._existingAttachmentUrls.map(
              (url) => _AttachmentThumbnail(
                imageProvider: NetworkImage(url),
                onRemove: () {
                  setState(() {
                    _existingAttachmentUrls.remove(url);
                    _removedAttachmentUrls.add(url);
                  });
                },
              ),
            ),
            ..._newAttachments.map(
              (file) => _AttachmentThumbnail(
                imageProvider: FileImage(file),
                onRemove: () => setState(() => _newAttachments.remove(file)),
              ),
            ),
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
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _StandardSheetHandle(),
            const _StandardSheetHeader(title: '新增附件'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  _ReceiptScanSourceTile(
                    icon: Icons.camera_alt_outlined,
                    title: '拍照',
                    subtitle: '立即拍攝新的照片或收據',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _ReceiptScanSourceTile(
                    icon: Icons.photo_library_outlined,
                    title: '從相簿選取',
                    subtitle: '從裝置相簿挑選既有圖片',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
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

  // ─── Receipt Scan ─────────────────────────────────────────────────────────

  Future<void> _startReceiptScan() async {
    // Step 1: Pick image source + receipt language
    final selection =
        await showModalBottomSheet<
          ({ImageSource source, OcrLanguage language})
        >(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) {
            var selectedLanguage = OcrLanguage.auto;
            return StatefulBuilder(
              builder: (context, setSheetState) => SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _StandardSheetHandle(),
                        _StandardSheetHeader(
                          title: '掃描收據',
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        const Divider(height: 1),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '辨識語言',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children:
                                      const [
                                        (OcrLanguage.auto, '自動'),
                                        (OcrLanguage.chinese, '中文'),
                                        (OcrLanguage.japanese, '日文'),
                                        (OcrLanguage.english, '英文'),
                                      ].map((entry) {
                                        final language = entry.$1;
                                        final label = entry.$2;
                                        final isSelected =
                                            selectedLanguage == language;
                                        final colorScheme = Theme.of(
                                          context,
                                        ).colorScheme;

                                        return GestureDetector(
                                          onTap: () => setSheetState(
                                            () => selectedLanguage = language,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? colorScheme.primaryContainer
                                                        .withValues(alpha: 0.85)
                                                  : colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme
                                                          .outlineVariant,
                                                width: isSelected ? 1.6 : 1,
                                              ),
                                            ),
                                            child: Text(
                                              label,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: isSelected
                                                        ? colorScheme.primary
                                                        : colorScheme.onSurface,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '選擇來源',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _ReceiptScanSourceTile(
                                  icon: Icons.camera_alt_outlined,
                                  title: '拍照',
                                  subtitle: '立即拍攝紙本收據或點餐單',
                                  onTap: () => Navigator.pop(context, (
                                    source: ImageSource.camera,
                                    language: selectedLanguage,
                                  )),
                                ),
                                const SizedBox(height: 12),
                                _ReceiptScanSourceTile(
                                  icon: Icons.photo_library_outlined,
                                  title: '從相簿選取',
                                  subtitle: '使用已拍好的收據照片進行辨識',
                                  onTap: () => Navigator.pop(context, (
                                    source: ImageSource.gallery,
                                    language: selectedLanguage,
                                  )),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
    if (selection == null) return;

    // Step 2: Pick image
    final picked = await _imagePicker.pickImage(
      source: selection.source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Step 3: Navigate to scan result screen
    final members =
        ref.read(groupMembersProvider(widget.groupId)).valueOrNull ?? [];
    final groupCurrency =
        ref.read(groupDetailProvider(widget.groupId)).valueOrNull?.currency ??
        AppConstants.defaultCurrency;
    final exchangeRateCurrencies =
        ref
            .read(groupExchangeRatesProvider(widget.groupId))
            .valueOrNull
            ?.map((r) => r.currency)
            .toList() ??
        [];
    final availableCurrencies = [groupCurrency, ...exchangeRateCurrencies];
    final importData = await Navigator.of(context).push<ReceiptImportData>(
      MaterialPageRoute(
        builder: (_) => ReceiptScanResultScreen(
          imageFile: File(picked.path),
          language: selection.language,
          members: members,
          availableCurrencies: availableCurrencies,
          initialCurrency: _selectedCurrency ?? groupCurrency,
        ),
      ),
    );
    if (importData == null || !mounted) return;

    // Step 4: Apply import data to form
    _applyReceiptImport(importData);
  }

  void _applyReceiptImport(ReceiptImportData data) {
    setState(() {
      // Set amount
      _amountController.text = data.total.toStringAsFixed(
        data.total == data.total.roundToDouble() ? 0 : 2,
      );

      // Set description
      if (_descriptionController.text.trim().isEmpty) {
        _descriptionController.text = '收據掃描';
      }

      // Switch to itemized split and populate items
      if (data.items.isNotEmpty) {
        _splitType = SplitType.itemized;
        _splitTypeExpanded = true;

        // Clear existing items
        for (final item in _itemEntries) {
          item.nameController.dispose();
          item.amountController.dispose();
        }
        _itemEntries.clear();

        // Populate from scan result
        // Get current group members for sharedByUserIds fallback
        final allMemberIds =
            ref
                .read(groupMembersProvider(widget.groupId))
                .valueOrNull
                ?.map((m) => m.userId)
                .toSet() ??
            {};

        for (var i = 0; i < data.items.length; i++) {
          final item = data.items[i];
          final assignedIds =
              i < data.itemMemberIds.length && data.itemMemberIds[i].isNotEmpty
              ? data.itemMemberIds[i]
              : Set.of(allMemberIds);
          _itemEntries.add(
            _ItemEntry(
              nameController: TextEditingController(text: item.name),
              amountController: TextEditingController(
                text: item.amount > 0
                    ? item.amount.toStringAsFixed(
                        item.amount == item.amount.roundToDouble() ? 0 : 2,
                      )
                    : '',
              ),
              sharedByUserIds: assignedIds,
            ),
          );
        }

        // Apply currency from receipt screen if provided
        if (data.currency != null) {
          _selectedCurrency = data.currency;
        }
      }

      // Add receipt image as attachment
      _newAttachments.add(data.imageFile);
    });
  }

  // ─── Category Dialogs ────────────────────────────────────────────────────

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddCategorySheet(),
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
        final ratioSplits = SplitCalculator.calculateRatioSplits(
          amount,
          ratios,
        );
        return memberIds
            .map(
              (id) => {
                'user_id': id,
                'amount': ratioSplits[id] ?? 0.0,
                'split_type': 'custom_ratio',
              },
            )
            .toList();

      case SplitType.fixedAmount:
        final amounts = _getFixedAmountsMap();
        return memberIds
            .map(
              (id) => {
                'user_id': id,
                'amount': amounts[id] ?? 0.0,
                'split_type': 'fixed_amount',
              },
            )
            .toList();

      case SplitType.itemized:
        return _buildItemizedSplitsPayload();
    }
  }

  List<Map<String, dynamic>> _buildItemizedSplitsPayload() {
    final perUser = <String, double>{};
    for (final item in _buildItemsPayload()) {
      final itemAmount = (item['amount'] as num).toDouble();
      final sharedByUserIds = (item['shared_by_user_ids'] as List)
          .cast<String>();
      if (itemAmount <= 0 || sharedByUserIds.isEmpty) continue;
      final share = itemAmount / sharedByUserIds.length;
      for (final userId in sharedByUserIds) {
        perUser[userId] = (perUser[userId] ?? 0) + share;
      }
    }

    return perUser.entries
        .map(
          (e) => {
            'user_id': e.key,
            'amount': double.parse(e.value.toStringAsFixed(2)),
            'split_type': 'itemized',
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _buildItemsPayload() {
    return _itemEntries
        .map(
          (item) => {
            'name': item.nameController.text.trim(),
            'amount': double.parse(
              ((double.tryParse(item.amountController.text) ?? 0))
                  .toStringAsFixed(2),
            ),
            'shared_by_user_ids': item.sharedByUserIds.toList(),
          },
        )
        .where(
          (item) =>
              (item['name'] as String).isNotEmpty &&
              ((item['amount'] as double) > 0) &&
              (item['shared_by_user_ids'] as List).isNotEmpty,
        )
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('指定金額加總必須等於總金額')));
        return;
      }
    }

    if (_splitType == SplitType.itemized) {
      if (_itemEntries.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請至少新增一個品項')));
        return;
      }
      for (var i = 0; i < _itemEntries.length; i++) {
        final item = _itemEntries[i];
        final itemName = item.nameController.text.trim();
        final itemAmount = double.tryParse(item.amountController.text) ?? 0;
        if (itemName.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('請填寫品項 ${i + 1} 的名稱')));
          return;
        }
        if (itemAmount <= 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('請填寫品項 ${i + 1} 的正確金額')));
          return;
        }
        if (item.sharedByUserIds.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('請至少選擇品項 ${i + 1} 的一位分攤者')));
          return;
        }
      }
      double itemsTotal = 0;
      for (final item in _itemEntries) {
        itemsTotal += double.tryParse(item.amountController.text) ?? 0;
      }
      if ((amount - itemsTotal).abs() > 0.01) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('品項金額合計必須等於總金額')));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final hasAttachmentChanges =
        _newAttachments.isNotEmpty || _removedAttachmentUrls.isNotEmpty;

    if (widget.isEditing) {
      final splits = _buildSplitsPayload(amount);
      final items = _buildItemsPayload();
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
        items: items,
      );

      if (!mounted) return;

      await result.fold(
        (failure) async {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('附件上傳失敗：$e')));
              }
            }
          }
          setState(() => _isSubmitting = false);
          ref.invalidate(expensesProvider(widget.groupId));
          ref.invalidate(expenseDetailProvider(widget.expenseId!));
          ref.invalidate(balancesProvider(widget.groupId));
          if (mounted) context.go('/groups/${widget.groupId}');
        },
      );
    } else {
      final splits = _buildSplitsPayload(amount);
      final items = _buildItemsPayload();
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
        items: items,
      );

      if (!mounted) return;

      await result.fold(
        (failure) async {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
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
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
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
              await ds.updateAttachmentUrls(expenseId: expenseId, urls: urls);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('附件上傳失敗：$e')));
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
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 18,
                    ),
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

  void _disposeItemEntries() {
    for (final item in _itemEntries) {
      item.nameController.dispose();
      item.amountController.dispose();
    }
    _itemEntries.clear();
  }

  void _hydrateItemEntries(
    List<ExpenseItemEntity> items, {
    Set<String>? validMemberIds,
  }) {
    _disposeItemEntries();
    for (final item in items) {
      final assignees = validMemberIds == null
          ? item.sharedByUserIds.toSet()
          : item.sharedByUserIds.where(validMemberIds.contains).toSet();
      _itemEntries.add(
        _ItemEntry(
          nameController: TextEditingController(text: item.name),
          amountController: TextEditingController(
            text: item.amount.truncateToDouble() == item.amount
                ? item.amount.toStringAsFixed(0)
                : item.amount.toStringAsFixed(2),
          ),
          sharedByUserIds: assignees,
        ),
      );
    }
  }

  Set<String> _collectSelectedMemberIdsFromItems() {
    final selectedIds = <String>{};
    for (final item in _itemEntries) {
      selectedIds.addAll(item.sharedByUserIds);
    }
    return selectedIds;
  }

  void _normalizeItemizedAssignments(List<GroupMemberEntity> members) {
    if (_itemEntries.isEmpty) return;

    final validMemberIds = {for (final member in members) member.userId};
    for (final item in _itemEntries) {
      item.sharedByUserIds.removeWhere((id) => !validMemberIds.contains(id));
      if (item.sharedByUserIds.isEmpty && validMemberIds.isNotEmpty) {
        item.sharedByUserIds.add(validMemberIds.first);
      }
    }

    if (_splitType != SplitType.itemized) return;

    final nextSelectedIds = _collectSelectedMemberIdsFromItems();
    if (nextSelectedIds.isNotEmpty &&
        nextSelectedIds.length != _selectedMemberIds.length) {
      _selectedMemberIds = nextSelectedIds;
      return;
    }
    if (nextSelectedIds.difference(_selectedMemberIds).isNotEmpty ||
        _selectedMemberIds.difference(nextSelectedIds).isNotEmpty) {
      _selectedMemberIds = nextSelectedIds;
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

class _ScrollableMemberSelectorRow extends StatefulWidget {
  const _ScrollableMemberSelectorRow({
    required this.enableSmartHint,
    required this.itemCount,
    required this.itemBuilder,
  });

  final bool enableSmartHint;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_ScrollableMemberSelectorRow> createState() =>
      _ScrollableMemberSelectorRowState();
}

class _ScrollableMemberSelectorRowState
    extends State<_ScrollableMemberSelectorRow> {
  late final ScrollController _scrollController;
  bool _canScroll = false;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHintState());
  }

  @override
  void didUpdateWidget(covariant _ScrollableMemberSelectorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.enableSmartHint != widget.enableSmartHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateHintState());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.enableSmartHint || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final canScroll = position.maxScrollExtent > 0;
    final shouldShow =
        canScroll && position.pixels < position.maxScrollExtent - 8;

    if (canScroll != _canScroll || shouldShow != _showHint) {
      setState(() {
        _canScroll = canScroll;
        _showHint = shouldShow;
      });
    }
  }

  void _updateHintState() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final canScroll = widget.enableSmartHint && position.maxScrollExtent > 0;
    final shouldShow =
        canScroll && position.pixels < position.maxScrollExtent - 8;

    setState(() {
      _canScroll = canScroll;
      _showHint = shouldShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ClipRect(
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.hardEdge,
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: widget.itemBuilder,
          ),
        ),
        AnimatedOpacity(
          opacity: _showHint ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colorScheme.surface.withValues(alpha: 0),
                      colorScheme.surface.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.swipe_left_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StandardSheetHandle extends StatelessWidget {
  const _StandardSheetHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _StandardSheetHeader extends StatelessWidget {
  const _StandardSheetHeader({required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        ],
      ),
    );
  }
}

class _ReceiptScanSourceTile extends StatelessWidget {
  const _ReceiptScanSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

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
              ? colorScheme.surface
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: colorScheme.outlineVariant, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isSelected
                  ? colorScheme.primary
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
                      ? colorScheme.primary
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

class _SplitModeOption {
  const _SplitModeOption({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
  });

  final SplitType type;
  final IconData icon;
  final String title;
  final String description;
}

class _SplitModeCard extends StatelessWidget {
  const _SplitModeCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _SplitModeOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 112,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.75)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  option.icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                option.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _selectedIcon != null) {
      Navigator.of(context).pop({'name': name, 'icon': _selectedIcon!});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSubmit =
        _nameController.text.trim().isNotEmpty && _selectedIcon != null;
    final entries = categoryIconMap.entries.toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  '新增自訂分類',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    decoration: const InputDecoration(
                      labelText: '分類名稱',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '選擇圖示',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isSelected = _selectedIcon == entry.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? null
                                : Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Icon(
                            entry.value,
                            size: 24,
                            color: isSelected
                                ? Colors.white
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    child: const Text('新增分類'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
