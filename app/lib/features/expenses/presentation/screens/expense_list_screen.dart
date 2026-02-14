import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/expense_card.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate realtime subscription for expenses
    ref.listen(realtimeExpensesProvider(groupId), (prev, next) {});

    final expensesAsync = ref.watch(expensesProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('消費紀錄')),
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
          final memberMap = {for (final m in members) m.userId: m.displayName};
          final customCategories =
              ref.watch(groupCategoriesProvider(groupId)).valueOrNull ?? [];

          // Build a flat list of date headers + expense items
          final items = <_ListItem>[];
          String? lastDateKey;
          for (final expense in expenses) {
            final dateKey = _formatDateKey(expense.expenseDate);
            if (dateKey != lastDateKey) {
              items.add(_DateHeader(dateKey));
              lastDateKey = dateKey;
            }
            items.add(_ExpenseItem(expense));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesProvider(groupId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is _DateHeader) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 16,
                      bottom: 8,
                    ),
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  );
                }
                final expense = (item as _ExpenseItem).expense;
                return ExpenseCard(
                  expense: expense,
                  paidByName: memberMap[expense.paidBy],
                  customCategories: customCategories,
                  onTap: () =>
                      context.push('/groups/$groupId/expenses/${expense.id}'),
                );
              },
            ),
          );
        },
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
}

class _ExpenseItem extends _ListItem {
  _ExpenseItem(this.expense);
  final ExpenseEntity expense;
}
