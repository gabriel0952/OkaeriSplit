import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final recentExpensesProvider =
    FutureProvider<List<ExpenseEntity>>((ref) async {
  final groupsResult = ref.watch(groupsProvider);
  final groups = groupsResult.valueOrNull ?? [];

  if (groups.isEmpty) return [];

  final allExpenses = <ExpenseEntity>[];

  for (final group in groups) {
    try {
      final expenses = await ref.watch(expensesProvider(group.id).future);
      allExpenses.addAll(expenses);
    } catch (_) {
      // Skip groups whose expenses can't be loaded (e.g. offline + no cache).
    }
  }

  allExpenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

  return allExpenses.take(10).toList();
});
