import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/skeleton_box.dart';
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
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _showSearch = false;
  Set<String> _selectedCategories = {};
  String? _selectedPayer;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // Flush pending expenses as soon as this screen is open and online.
    // This is a reliable fallback in case the global listener in main.dart
    // missed the connectivity change event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isOnlineProvider)) {
        ref.read(syncServiceProvider).flush();
      }
      // Also listen for subsequent connectivity changes while on this screen.
      ref.listenManual(isOnlineProvider, (prev, next) {
        if (next == true && prev == false) {
          ref.read(syncServiceProvider).flush();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        // 展開後自動 focus
        Future.microtask(() => _searchFocusNode.requestFocus());
      } else {
        // 收起時清除查詢
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
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

  int get _advancedFilterCount =>
      (_selectedCategories.isNotEmpty ? 1 : 0) +
      (_selectedPayer != null ? 1 : 0) +
      (_dateRange != null ? 1 : 0);

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _advancedFilterCount > 0;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategories = {};
      _selectedPayer = null;
      _dateRange = null;
    });
  }

  void _showFilterSheet(BuildContext context) {
    final groupId = widget.groupId;
    final expenses =
        ref.read(expensesProvider(groupId)).valueOrNull ?? [];
    final members =
        ref.read(groupMembersProvider(groupId)).valueOrNull ?? [];
    final customCategories =
        ref.read(groupCategoriesProvider(groupId)).valueOrNull ?? [];
    final allCategories = _collectCategories(expenses, customCategories);
    final memberMap = {for (final m in members) m.userId: m.displayName};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var localCategories = Set<String>.from(_selectedCategories);
        var localPayer = _selectedPayer;
        var localDateRange = _dateRange;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void applyAndClose() {
              setState(() {
                _selectedCategories = localCategories;
                _selectedPayer = localPayer;
                _dateRange = localDateRange;
              });
              Navigator.of(sheetCtx).pop();
            }

            final hasLocalFilters = localCategories.isNotEmpty ||
                localPayer != null ||
                localDateRange != null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3),
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
                          '篩選條件',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const Spacer(),
                        if (hasLocalFilters)
                          TextButton(
                            onPressed: () => setSheetState(() {
                              localCategories = {};
                              localPayer = null;
                              localDateRange = null;
                            }),
                            child: const Text('全部清除'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Categories
                          if (allCategories.isNotEmpty) ...[
                            Text(
                              '分類',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: allCategories.map((cat) {
                                final selected =
                                    localCategories.contains(cat);
                                return FilterChip(
                                  label: Text(
                                      _categoryLabel(cat, customCategories)),
                                  selected: selected,
                                  onSelected: (_) => setSheetState(() {
                                    if (selected) {
                                      localCategories = {
                                        ...localCategories,
                                      }..remove(cat);
                                    } else {
                                      localCategories = {
                                        ...localCategories,
                                        cat,
                                      };
                                    }
                                  }),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Payer
                          if (memberMap.isNotEmpty) ...[
                            Text(
                              '付款人',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('全部'),
                                  selected: localPayer == null,
                                  onSelected: (_) =>
                                      setSheetState(() => localPayer = null),
                                ),
                                ...memberMap.entries.map((e) => ChoiceChip(
                                      label: Text(e.value),
                                      selected: localPayer == e.key,
                                      onSelected: (_) => setSheetState(
                                          () => localPayer = e.key),
                                    )),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Date range
                          Text(
                            '日期範圍',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 10),
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.date_range_outlined),
                              title: Text(
                                localDateRange != null
                                    ? '${DateFormat('MM/dd').format(localDateRange!.start)} － ${DateFormat('MM/dd').format(localDateRange!.end)}'
                                    : '不限日期',
                                style: localDateRange != null
                                    ? Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        )
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                              ),
                              trailing: localDateRange != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setSheetState(
                                          () => localDateRange = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  initialDateRange: localDateRange,
                                );
                                if (picked != null) {
                                  setSheetState(() => localDateRange = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Apply button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton(
                      onPressed: applyAndClose,
                      child: const Text('套用篩選'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;

    // Activate realtime subscription for expenses
    ref.listen(realtimeExpensesProvider(groupId), (prev, next) {});

    final expensesAsync = ref.watch(expensesProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    final pendingCount = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消費紀錄'),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '待同步 $pendingCount 筆',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            tooltip: '搜尋',
            onPressed: _toggleSearch,
          ),
          Badge(
            isLabelVisible: _advancedFilterCount > 0,
            label: Text('$_advancedFilterCount'),
            child: IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '篩選',
              onPressed: () => _showFilterSheet(context),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/groups/$groupId/add-expense'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey(expensesAsync.valueOrNull?.length ?? -1),
                child: expensesAsync.when(
        loading: () => const ExpenseListSkeleton(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(expensesProvider(groupId)),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: '尚無消費紀錄',
              subtitle: '點擊 + 新增第一筆消費',
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

          // Build grouped list by date
          final groups = <_DateGroup>[];
          String? lastDateKey;
          List<ExpenseEntity> currentExpenses = [];
          double dailySubtotal = 0;
          for (final expense in filtered) {
            final dateKey = _formatDateKey(expense.expenseDate);
            if (dateKey != lastDateKey) {
              if (lastDateKey != null) {
                groups.add(_DateGroup(lastDateKey, dailySubtotal, [...currentExpenses]));
              }
              currentExpenses = [];
              dailySubtotal = 0;
              lastDateKey = dateKey;
            }
            dailySubtotal += expense.amount;
            currentExpenses.add(expense);
          }
          if (lastDateKey != null) {
            groups.add(_DateGroup(lastDateKey, dailySubtotal, currentExpenses));
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Upload any pending expenses first, then refresh the list.
              if (ref.read(isOnlineProvider)) {
                await ref.read(syncServiceProvider).flush();
              }
              ref.invalidate(expensesProvider(groupId));
            },
            child: Column(
              children: [
                // 搜尋列（點擊搜尋圖示才展開）
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _showSearch
                      ? _SearchBar(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                          onClearSearch: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : const SizedBox.shrink(),
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
                          itemCount: groups.length + 1,
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

                            final group = groups[index - 1];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: index == 1 ? 8 : 16,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        group.label,
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
                                        '$groupCurrency ${group.subtotal.toStringAsFixed(0)}',
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
                                ),
                                Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: group.expenses
                                        .map((expense) => ExpenseCard(
                                              expense: expense,
                                              paidByName:
                                                  memberMap[expense.paidBy],
                                              customCategories: customCategories,
                                              showCard: false,
                                              onTap: expense.isPending
                                                  ? null
                                                  : () => context.push(
                                                        '/groups/$groupId/expenses/${expense.id}',
                                                      ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
              ),   // KeyedSubtree
            ),     // AnimatedSwitcher
          ),
        ],
      ),
    );
  }
}

// --- 常駐搜尋列 ---

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '搜尋消費描述…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClearSearch,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
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

class _DateGroup {
  _DateGroup(this.label, this.subtotal, this.expenses);
  final String label;
  final double subtotal;
  final List<ExpenseEntity> expenses;
}
