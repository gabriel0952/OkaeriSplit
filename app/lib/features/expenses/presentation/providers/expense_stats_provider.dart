import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_stats_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final categoryStatsProvider =
    Provider.family<List<CategoryStatEntity>, String>((ref, groupId) {
  final expensesAsync = ref.watch(expensesProvider(groupId));
  final expenses = expensesAsync.valueOrNull ?? [];

  if (expenses.isEmpty) return [];

  final categoryTotals = <ExpenseCategory, double>{};
  double grandTotal = 0;

  for (final expense in expenses) {
    categoryTotals[expense.category] =
        (categoryTotals[expense.category] ?? 0) + expense.amount;
    grandTotal += expense.amount;
  }

  if (grandTotal == 0) return [];

  final stats = categoryTotals.entries
      .map(
        (e) => CategoryStatEntity(
          category: e.key,
          totalAmount: e.value,
          percentage: e.value / grandTotal * 100,
        ),
      )
      .toList();

  stats.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return stats;
});

final monthlyStatsProvider =
    Provider.family<List<MonthlyStatEntity>, String>((ref, groupId) {
  final expensesAsync = ref.watch(expensesProvider(groupId));
  final expenses = expensesAsync.valueOrNull ?? [];

  if (expenses.isEmpty) return [];

  final monthlyTotals = <String, double>{};
  final formatter = DateFormat('yyyy-MM');

  for (final expense in expenses) {
    final key = formatter.format(expense.expenseDate);
    monthlyTotals[key] = (monthlyTotals[key] ?? 0) + expense.amount;
  }

  final stats = monthlyTotals.entries
      .map(
        (e) => MonthlyStatEntity(
          yearMonth: e.key,
          totalAmount: e.value,
        ),
      )
      .toList();

  stats.sort((a, b) => a.yearMonth.compareTo(b.yearMonth));
  return stats;
});
