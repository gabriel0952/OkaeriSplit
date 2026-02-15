import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/expense_card.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  String? _selectedPayer;
  DateTimeRange? _dateRange;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseEntity> _applyFilters(List<ExpenseEntity> expenses) {
    var filtered = expenses;

    // Keyword search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((e) => e.description.toLowerCase().contains(query))
          .toList();
    }

    // Category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered
          .where((e) => _selectedCategories.contains(e.category))
          .toList();
    }

    // Payer filter
    if (_selectedPayer != null) {
      filtered = filtered.where((e) => e.paidBy == _selectedPayer).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      filtered = filtered.where((e) {
        final date = DateTime(
          e.expenseDate.year,
          e.expenseDate.month,
          e.expenseDate.day,
        );
        return !date.isBefore(_dateRange!.start) &&
            !date.isAfter(_dateRange!.end);
      }).toList();
    }

    return filtered;
  }

  Set<String> _collectCategories(
    List<ExpenseEntity> expenses,
    List<GroupCategoryEntity> customCategories,
  ) {
    return expenses.map((e) => e.category).toSet();
  }

  String _categoryLabel(
    String key,
    List<GroupCategoryEntity> customCategories,
  ) {
    if (builtInCategoryLabels.containsKey(key)) {
      return builtInCategoryLabels[key]!;
    }
    final custom = customCategories.where((c) => c.id == key);
    if (custom.isNotEmpty) return custom.first.name;
    return key;
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _selectedPayer != null ||
      _dateRange != null;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategories = {};
      _selectedPayer = null;
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;

    // Activate realtime subscription for expenses
    ref.listen(realtimeExpensesProvider(groupId), (prev, next) {});

    final expensesAsync = ref.watch(expensesProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('消費紀錄'),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: _hasActiveFilters
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: '篩選',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/groups/$groupId/add-expense'),
        child: const Icon(Icons.add),
      ),
      body: expensesAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(expensesProvider(groupId)),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '還沒有消費紀錄',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '點擊右下角按鈕新增第一筆消費',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          final members = membersAsync.valueOrNull ?? [];
          final memberMap = {
            for (final m in members) m.userId: m.displayName,
          };
          final customCategories =
              ref.watch(groupCategoriesProvider(groupId)).valueOrNull ?? [];

          // Apply filters
          final filtered = _applyFilters(expenses);

          // Calculate group total (from filtered results)
          final groupTotal = filtered.fold<double>(
            0,
            (sum, e) => sum + e.amount,
          );
          final groupCurrency =
              expenses.isNotEmpty ? expenses.first.currency : '';

          // Collect available categories for chips
          final allCategories =
              _collectCategories(expenses, customCategories);

          // Build a flat list of date headers + expense items
          final items = <_ListItem>[];
          String? lastDateKey;
          double dailySubtotal = 0;
          int lastHeaderIndex = -1;
          for (final expense in filtered) {
            final dateKey = _formatDateKey(expense.expenseDate);
            if (dateKey != lastDateKey) {
              if (lastHeaderIndex >= 0) {
                (items[lastHeaderIndex] as _DateHeader).subtotal =
                    dailySubtotal;
              }
              dailySubtotal = 0;
              items.add(_DateHeader(dateKey));
              lastHeaderIndex = items.length - 1;
              lastDateKey = dateKey;
            }
            dailySubtotal += expense.amount;
            items.add(_ExpenseItem(expense));
          }
          if (lastHeaderIndex >= 0) {
            (items[lastHeaderIndex] as _DateHeader).subtotal = dailySubtotal;
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesProvider(groupId));
            },
            child: Column(
              children: [
                // Search & filter bar
                if (_showFilters)
                  _FilterSection(
                    searchController: _searchController,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    allCategories: allCategories,
                    selectedCategories: _selectedCategories,
                    onCategoryToggled: (cat) {
                      setState(() {
                        if (_selectedCategories.contains(cat)) {
                          _selectedCategories = {..._selectedCategories}
                            ..remove(cat);
                        } else {
                          _selectedCategories = {..._selectedCategories, cat};
                        }
                      });
                    },
                    categoryLabel: (key) =>
                        _categoryLabel(key, customCategories),
                    memberMap: memberMap,
                    selectedPayer: _selectedPayer,
                    onPayerChanged: (payer) =>
                        setState(() => _selectedPayer = payer),
                    dateRange: _dateRange,
                    onDateRangePicked: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateRange,
                      );
                      if (picked != null) {
                        setState(() => _dateRange = picked);
                      }
                    },
                    onDateRangeCleared: () =>
                        setState(() => _dateRange = null),
                    hasActiveFilters: _hasActiveFilters,
                    onClearFilters: _clearFilters,
                  ),

                // Content
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '沒有符合條件的消費',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _clearFilters,
                                child: const Text('清除篩選'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.summarize_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _hasActiveFilters
                                                ? '篩選結果'
                                                : '群組消費總額',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$groupCurrency ${groupTotal.toStringAsFixed(0)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${filtered.length} 筆',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final item = items[index - 1];
                            if (item is _DateHeader) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: index == 1 ? 8 : 16,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      item.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$groupCurrency ${item.subtotal.toStringAsFixed(0)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final expense = (item as _ExpenseItem).expense;
                            return ExpenseCard(
                              expense: expense,
                              paidByName: memberMap[expense.paidBy],
                              customCategories: customCategories,
                              onTap: () => context.push(
                                '/groups/$groupId/expenses/${expense.id}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Filter section widget ---

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.searchController,
    required this.onSearchChanged,
    required this.allCategories,
    required this.selectedCategories,
    required this.onCategoryToggled,
    required this.categoryLabel,
    required this.memberMap,
    required this.selectedPayer,
    required this.onPayerChanged,
    required this.dateRange,
    required this.onDateRangePicked,
    required this.onDateRangeCleared,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Set<String> allCategories;
  final Set<String> selectedCategories;
  final ValueChanged<String> onCategoryToggled;
  final String Function(String) categoryLabel;
  final Map<String, String> memberMap;
  final String? selectedPayer;
  final ValueChanged<String?> onPayerChanged;
  final DateTimeRange? dateRange;
  final VoidCallback onDateRangePicked;
  final VoidCallback onDateRangeCleared;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
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

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: inputTheme.copyWith(
              hintText: '搜尋消費描述...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),

          // Category chips
          if (allCategories.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allCategories.map((cat) {
                  final selected = selectedCategories.contains(cat);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        categoryLabel(cat),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: selected,
                      onSelected: (_) => onCategoryToggled(cat),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Payer + date range row
          Row(
            children: [
              // Payer dropdown
              Expanded(
                child: InputDecorator(
                  decoration: inputTheme.copyWith(
                    labelText: '付款人',
                    prefixIcon: const Icon(Icons.person_outlined),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPayer,
                      isExpanded: true,
                      isDense: true,
                      style: Theme.of(context).textTheme.bodyLarge,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('全部'),
                        ),
                        ...memberMap.entries.map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: onPayerChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date range
              Expanded(
                child: InkWell(
                  onTap: onDateRangePicked,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: inputTheme.copyWith(
                      labelText: '日期範圍',
                      prefixIcon: const Icon(Icons.date_range_outlined),
                      suffixIcon: dateRange != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: onDateRangeCleared,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                    ),
                    child: Text(
                      dateRange != null
                          ? '${DateFormat('MM/dd').format(dateRange!.start)} - ${DateFormat('MM/dd').format(dateRange!.end)}'
                          : '全部',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Clear filters button
          if (hasActiveFilters) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('清除所有篩選'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Helpers for date-grouped list ---

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

String _formatDateKey(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  final weekday = _weekdays[date.weekday - 1];
  final formatted = DateFormat('MM/dd').format(date);

  if (diff == 0) return '今天  $formatted';
  if (diff == 1) return '昨天  $formatted';
  if (date.year == now.year) return '$formatted  星期$weekday';
  return '${DateFormat('yyyy/MM/dd').format(date)}  星期$weekday';
}

sealed class _ListItem {}

class _DateHeader extends _ListItem {
  _DateHeader(this.label);
  final String label;
  double subtotal = 0;
}

class _ExpenseItem extends _ListItem {
  _ExpenseItem(this.expense);
  final ExpenseEntity expense;
}
