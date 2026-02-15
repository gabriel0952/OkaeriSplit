import 'dart:io';

import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/utils/split_calculator.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:app/features/expenses/presentation/widgets/icon_picker_dialog.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId, this.expenseId});

  final String groupId;
  final String? expenseId;

  bool get isEditing => expenseId != null;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
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

  // Attachments
  final List<File> _newAttachments = [];
  List<String> _existingAttachmentUrls = [];
  final List<String> _removedAttachmentUrls = [];
  final _imagePicker = ImagePicker();

  // Itemized split
  final List<_ItemEntry> _itemEntries = [];

  static const _supportedCurrencies = [
    'TWD',
    'USD',
    'JPY',
    'EUR',
    'GBP',
    'KRW',
    'CNY',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    for (final c in _ratioControllers.values) {
      c.dispose();
    }
    for (final c in _fixedAmountControllers.values) {
      c.dispose();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    // Load existing expense data in edit mode
    if (widget.isEditing && !_isLoaded) {
      final expenseAsync = ref.watch(expenseDetailProvider(widget.expenseId!));
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '編輯消費' : '新增消費')),
      body: membersAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(groupMembersProvider(widget.groupId)),
        ),
        data: (members) {
          // Initialize defaults
          if (_paidBy == null && currentUser != null) {
            _paidBy = currentUser.id;
          }
          if (_selectedMemberIds.isEmpty) {
            _selectedMemberIds = members.map((m) => m.userId).toSet();
          }
          _ensureControllers(members);

          final groupCurrency =
              groupAsync.valueOrNull?.currency ?? AppConstants.defaultCurrency;
          _selectedCurrency ??= groupCurrency;

          return _buildForm(context, members, _selectedCurrency!);
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<GroupMemberEntity> members,
    String currency,
  ) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final customCategoriesAsync =
        ref.watch(groupCategoriesProvider(widget.groupId));
    final customCategories = customCategoriesAsync.valueOrNull ?? [];

    final colorScheme = Theme.of(context).colorScheme;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );
    final inputTheme = InputDecoration(
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: focusedBorder,
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount + Currency row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _amountController,
                  decoration: inputTheme.copyWith(
                    labelText: '金額',
                    prefixText: '\$ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '請輸入金額';
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return '請輸入有效金額';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: inputTheme.copyWith(
                    labelText: '幣別',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCurrency,
                      isExpanded: true,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: _supportedCurrencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCurrency = value);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: inputTheme.copyWith(
              labelText: '描述',
              prefixIcon: const Icon(Icons.edit_outlined),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? '請輸入描述' : null,
          ),
          const SizedBox(height: 16),

          // Paid by + Date row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: inputTheme.copyWith(
                    labelText: '付款人',
                    prefixIcon: const Icon(Icons.person_outlined),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _paidBy,
                      isExpanded: true,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: members
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(
                                m.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _paidBy = value),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expenseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _expenseDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: inputTheme.copyWith(
                      labelText: '日期',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      DateFormat('yyyy/MM/dd').format(_expenseDate),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category
          _buildSectionLabel('分類'),
          const SizedBox(height: 8),
          CategoryPicker(
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
            customCategories: customCategories,
            onAddCategory: () => _showAddCategoryDialog(context),
            onDeleteCategory: (id) => _deleteCategory(id),
          ),
          const SizedBox(height: 20),

          // Note
          TextFormField(
            controller: _noteController,
            decoration: inputTheme.copyWith(
              labelText: '備註（選填）',
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Attachments
          _buildSectionLabel('收據/照片'),
          const SizedBox(height: 8),
          _buildAttachmentSection(context),
          const SizedBox(height: 20),

          const Divider(),
          const SizedBox(height: 12),

          // Split type selector
          _buildSectionLabel('分帳方式'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: SplitType.values.map((type) {
              final selected = _splitType == type;
              return ChoiceChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (_) => setState(() => _splitType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Itemized split mode
          if (_splitType == SplitType.itemized) ...[
            _buildSectionLabel('品項'),
            const SizedBox(height: 8),
            ..._buildItemizedList(members),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _itemEntries.add(_ItemEntry(
                    nameController: TextEditingController(),
                    amountController: TextEditingController(),
                    sharedByUserIds: members.map((m) => m.userId).toSet(),
                  ));
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增品項'),
            ),
            if (amount > 0) _buildItemizedHint(amount),
          ],

          // Non-itemized split
          if (_splitType != SplitType.itemized) ...[
            // Split members
            _buildSectionLabel('分帳成員'),
            const SizedBox(height: 8),
            ..._buildMemberSplitList(members, amount),

            // Fixed amount validation hint
            if (_splitType == SplitType.fixedAmount && amount > 0)
              _buildFixedAmountHint(amount),
          ],

          const SizedBox(height: 24),

          // Submit
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isSubmitting ? null : () => _handleSubmit(currency),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    String? selectedIcon;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增自訂分類'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '分類名稱',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('圖示：'),
                  const SizedBox(width: 8),
                  if (selectedIcon != null)
                    Icon(resolveIcon(selectedIcon!), size: 24),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final icon = await showDialog<String>(
                        context: context,
                        builder: (_) => const IconPickerDialog(),
                      );
                      if (icon != null) {
                        setDialogState(() => selectedIcon = icon);
                      }
                    },
                    child: Text(selectedIcon == null ? '選擇圖示' : '更換'),
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
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty && selectedIcon != null) {
                  Navigator.of(context).pop({
                    'name': name,
                    'icon': selectedIcon!,
                  });
                }
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
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
    // If the deleted category was selected, reset to default
    final customCategories =
        ref.read(groupCategoriesProvider(widget.groupId)).valueOrNull ?? [];
    final stillExists = customCategories.any((c) => c.name == _category);
    if (!stillExists && !builtInCategoryLabels.containsKey(_category)) {
      setState(() => _category = 'food');
    }
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  List<Widget> _buildMemberSplitList(
    List<GroupMemberEntity> members,
    double amount,
  ) {
    switch (_splitType) {
      case SplitType.equal:
        return _buildEqualSplitList(members, amount);
      case SplitType.customRatio:
        return _buildRatioSplitList(members, amount);
      case SplitType.fixedAmount:
        return _buildFixedAmountSplitList(members, amount);
      case SplitType.itemized:
        return []; // Handled separately by _buildItemizedList
    }
  }

  List<Widget> _buildEqualSplitList(
    List<GroupMemberEntity> members,
    double amount,
  ) {
    final splitAmounts = SplitCalculator.calculateEqualSplits(
      amount,
      _selectedMemberIds.length,
    );

    return members.map((member) {
      final isSelected = _selectedMemberIds.contains(member.userId);
      final index = _selectedMemberIds.toList().indexOf(member.userId);
      final splitAmount = isSelected && splitAmounts.isNotEmpty && index >= 0
          ? splitAmounts[index]
          : 0.0;

      return CheckboxListTile(
        value: isSelected,
        onChanged: (checked) {
          setState(() {
            if (checked == true) {
              _selectedMemberIds.add(member.userId);
            } else if (_selectedMemberIds.length > 1) {
              _selectedMemberIds.remove(member.userId);
            }
          });
        },
        title: Text(member.displayName),
        subtitle:
            isSelected && amount > 0
                ? Text('\$${splitAmount.toStringAsFixed(2)}')
                : null,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }).toList();
  }

  List<Widget> _buildRatioSplitList(
    List<GroupMemberEntity> members,
    double amount,
  ) {
    // Build ratios map from controllers
    final ratios = <String, int>{};
    for (final id in _selectedMemberIds) {
      final text = _ratioControllers[id]?.text ?? '1';
      ratios[id] = int.tryParse(text) ?? 1;
    }

    final ratioSplits =
        amount > 0
            ? SplitCalculator.calculateRatioSplits(amount, ratios)
            : <String, double>{};

    return members.map((member) {
      final isSelected = _selectedMemberIds.contains(member.userId);
      final splitAmount = ratioSplits[member.userId] ?? 0.0;

      return CheckboxListTile(
        value: isSelected,
        onChanged: (checked) {
          setState(() {
            if (checked == true) {
              _selectedMemberIds.add(member.userId);
            } else if (_selectedMemberIds.length > 1) {
              _selectedMemberIds.remove(member.userId);
            }
          });
        },
        title: Row(
          children: [
            Expanded(child: Text(member.displayName)),
            if (isSelected)
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _ratioControllers[member.userId],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ),
        subtitle:
            isSelected && amount > 0
                ? Text('\$${splitAmount.toStringAsFixed(2)}')
                : null,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }).toList();
  }

  List<Widget> _buildFixedAmountSplitList(
    List<GroupMemberEntity> members,
    double amount,
  ) {
    return members.map((member) {
      final isSelected = _selectedMemberIds.contains(member.userId);

      return CheckboxListTile(
        value: isSelected,
        onChanged: (checked) {
          setState(() {
            if (checked == true) {
              _selectedMemberIds.add(member.userId);
            } else if (_selectedMemberIds.length > 1) {
              _selectedMemberIds.remove(member.userId);
            }
          });
        },
        title: Row(
          children: [
            Expanded(child: Text(member.displayName)),
            if (isSelected)
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _fixedAmountControllers[member.userId],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }).toList();
  }

  Widget _buildFixedAmountHint(double amount) {
    final amounts = _getFixedAmountsMap();
    final diff = SplitCalculator.fixedAmountDifference(amount, amounts);

    if (diff.abs() < 0.01) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
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
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        diff > 0
            ? '還差 \$${diff.toStringAsFixed(2)} 未分配'
            : '超出 \$${diff.abs().toStringAsFixed(2)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      ),
    );
  }

  Map<String, double> _getFixedAmountsMap() {
    final amounts = <String, double>{};
    for (final id in _selectedMemberIds) {
      final text = _fixedAmountControllers[id]?.text ?? '';
      amounts[id] = double.tryParse(text) ?? 0;
    }
    return amounts;
  }

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

  /// Aggregate per-user amounts from itemized entries.
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

  List<Widget> _buildItemizedList(List<GroupMemberEntity> members) {
    return _itemEntries.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
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
                      decoration: const InputDecoration(
                        labelText: '品項名稱',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: item.amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '金額',
                        prefixText: '\$ ',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
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
                children: members.map((m) {
                  final selected = item.sharedByUserIds.contains(m.userId);
                  return FilterChip(
                    label: Text(
                      m.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
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
            ? '還差 \$${diff.toStringAsFixed(2)} 未分配'
            : '超出 \$${diff.abs().toStringAsFixed(2)}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing attachments (from server)
        ..._existingAttachmentUrls.map((url) => _AttachmentThumbnail(
              imageProvider: NetworkImage(url),
              onRemove: () {
                setState(() {
                  _existingAttachmentUrls.remove(url);
                  _removedAttachmentUrls.add(url);
                });
              },
            )),
        // New local attachments
        ..._newAttachments.map((file) => _AttachmentThumbnail(
              imageProvider: FileImage(file),
              onRemove: () => setState(() => _newAttachments.remove(file)),
            )),
        // Add button
        InkWell(
          onTap: _pickAttachment,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 80,
            height: 80,
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

  /// Upload new attachments and remove deleted ones. Returns final URL list.
  Future<List<String>> _processAttachments(String expenseId) async {
    final ds = ref.read(supabaseExpenseDataSourceProvider);

    // Remove deleted attachments from storage
    for (final url in _removedAttachmentUrls) {
      try {
        await ds.removeAttachment(url);
      } catch (_) {
        // Ignore storage removal errors
      }
    }

    // Upload new attachments
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
    if (!_formKey.currentState!.validate()) return;
    if (_splitType != SplitType.itemized && _selectedMemberIds.isEmpty) return;

    final amount = double.parse(_amountController.text);

    // Validate fixed amounts
    if (_splitType == SplitType.fixedAmount) {
      final amounts = _getFixedAmountsMap();
      if (!SplitCalculator.validateFixedAmounts(amount, amounts)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('指定金額加總必須等於總金額')),
        );
        return;
      }
    }

    // Validate itemized
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

    final hasAttachmentChanges = _newAttachments.isNotEmpty ||
        _removedAttachmentUrls.isNotEmpty;

    if (widget.isEditing) {
      final splits = _buildSplitsPayload(amount);
      final updateExpense = ref.read(updateExpenseUseCaseProvider);
      final result = await updateExpense(
        expenseId: widget.expenseId!,
        amount: amount,
        category: _category,
        description: _descriptionController.text.trim(),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (_) async {
          // Process attachments after successful update
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
        description: _descriptionController.text.trim(),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (expenseId) async {
          // Process attachments after successful creation
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
          if (mounted) context.pop();
        },
      );
    }
  }
}

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
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 80,
              height: 80,
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
                Icons.close,
                size: 14,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
