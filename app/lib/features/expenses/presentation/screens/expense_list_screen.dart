import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/expenses/presentation/widgets/expense_card.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesProvider(groupId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return ExpenseCard(
                  expense: expense,
                  paidByName: memberMap[expense.paidBy],
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
