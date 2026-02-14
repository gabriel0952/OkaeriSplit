import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/utils/split_calculator.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _expenseDate = DateTime.now();
  String? _paidBy;
  Set<String> _selectedMemberIds = {};
  bool _isSubmitting = false;
  bool _isLoaded = false;

  SplitType _splitType = SplitType.equal;
  String? _selectedCurrency;
  final Map<String, TextEditingController> _ratioControllers = {};
  final Map<String, TextEditingController> _fixedAmountControllers = {};

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

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '金額',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return '請輸入金額';
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) return '請輸入有效金額';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Currency
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: const InputDecoration(
              labelText: '幣別',
              border: OutlineInputBorder(),
            ),
            items: _supportedCurrencies
                .map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedCurrency = value);
            },
          ),
          const SizedBox(height: 16),

          // Paid by
          DropdownButtonFormField<String>(
            initialValue: _paidBy,
            decoration: const InputDecoration(
              labelText: '付款人',
              border: OutlineInputBorder(),
            ),
            items: members
                .map(
                  (m) => DropdownMenuItem(
                    value: m.userId,
                    child: Text(m.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _paidBy = value),
            validator: (value) => value == null ? '請選擇付款人' : null,
          ),
          const SizedBox(height: 16),

          // Category
          Text(
            '分類',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CategoryPicker(
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '描述',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? '請輸入描述' : null,
          ),
          const SizedBox(height: 16),

          // Note
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '備註（選填）',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Date
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('日期'),
            trailing: Text(
              DateFormat('yyyy/MM/dd').format(_expenseDate),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expenseDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _expenseDate = picked);
            },
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Split type selector
          Text(
            '分帳方式',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<SplitType>(
            segments: const [
              ButtonSegment(value: SplitType.equal, label: Text('均分')),
              ButtonSegment(
                value: SplitType.customRatio,
                label: Text('自訂比例'),
              ),
              ButtonSegment(
                value: SplitType.fixedAmount,
                label: Text('指定金額'),
              ),
            ],
            selected: {_splitType},
            onSelectionChanged: (selected) {
              setState(() => _splitType = selected.first);
            },
          ),
          const SizedBox(height: 16),

          // Split members
          Text(
            '分帳成員',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._buildMemberSplitList(members, amount),

          // Fixed amount validation hint
          if (_splitType == SplitType.fixedAmount && amount > 0)
            _buildFixedAmountHint(amount),

          const SizedBox(height: 24),

          // Submit
          FilledButton(
            onPressed: _isSubmitting ? null : () => _handleSubmit(currency),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? '儲存變更' : '新增消費'),
          ),
        ],
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
          style: TextStyle(color: Colors.green.shade700, fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        diff > 0
            ? '還差 \$${diff.toStringAsFixed(2)} 未分配'
            : '超出 \$${diff.abs().toStringAsFixed(2)}',
        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
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
    }
  }

  Future<void> _handleSubmit(String currency) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberIds.isEmpty) return;

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

    setState(() => _isSubmitting = true);

    final categorySnake = SupabaseExpenseDataSource.toSnakeCase(_category.name);

    if (widget.isEditing) {
      final splits = _buildSplitsPayload(amount);
      final updateExpense = ref.read(updateExpenseUseCaseProvider);
      final result = await updateExpense(
        expenseId: widget.expenseId!,
        amount: amount,
        category: categorySnake,
        description: _descriptionController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        expenseDate: _expenseDate,
        splits: splits,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (_) {
          ref.invalidate(expensesProvider(widget.groupId));
          ref.invalidate(expenseDetailProvider(widget.expenseId!));
          context.pop();
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
        category: categorySnake,
        description: _descriptionController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        expenseDate: _expenseDate,
        splits: splits,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (_) {
          ref.invalidate(expensesProvider(widget.groupId));
          context.pop();
        },
      );
    }
  }
}
