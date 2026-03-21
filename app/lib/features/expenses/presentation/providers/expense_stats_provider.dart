import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_stats_entity.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/groups/domain/entities/group_exchange_rate_entity.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

double _toBase(
  double amount,
  String currency,
  String groupCurrency,
  List<GroupExchangeRateEntity> rates,
) {
  if (currency == groupCurrency || groupCurrency.isEmpty) return amount;
  final rate = rates.where((r) => r.currency == currency).firstOrNull?.rate;
  return amount * (rate ?? 1.0);
}

final categoryStatsProvider =
    Provider.family<List<CategoryStatEntity>, String>((ref, groupId) {
  final expensesAsync = ref.watch(expensesProvider(groupId));
  final expenses = expensesAsync.valueOrNull ?? [];
  if (expenses.isEmpty) return [];

  final groupCurrency =
      ref.watch(groupDetailProvider(groupId)).valueOrNull?.currency ?? '';
  final rates =
      ref.watch(groupExchangeRatesProvider(groupId)).valueOrNull ?? [];

  final categoryTotals = <String, double>{};
  double grandTotal = 0;

  for (final expense in expenses) {
    final converted =
        _toBase(expense.amount, expense.currency, groupCurrency, rates);
    categoryTotals[expense.category] =
        (categoryTotals[expense.category] ?? 0) + converted;
    grandTotal += converted;
  }

  if (grandTotal == 0) return [];

  final stats = categoryTotals.entries
      .map(
        (e) => CategoryStatEntity(
          category: e.key,
          label: builtInCategoryLabels[e.key] ?? e.key,
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

  final groupCurrency =
      ref.watch(groupDetailProvider(groupId)).valueOrNull?.currency ?? '';
  final rates =
      ref.watch(groupExchangeRatesProvider(groupId)).valueOrNull ?? [];

  final monthlyTotals = <String, double>{};
  final formatter = DateFormat('yyyy-MM');

  for (final expense in expenses) {
    final key = formatter.format(expense.expenseDate);
    final converted =
        _toBase(expense.amount, expense.currency, groupCurrency, rates);
    monthlyTotals[key] = (monthlyTotals[key] ?? 0) + converted;
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
