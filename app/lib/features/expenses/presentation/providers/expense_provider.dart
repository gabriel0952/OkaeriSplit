import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:app/features/expenses/domain/usecases/create_expense.dart';
import 'package:app/features/expenses/domain/usecases/delete_expense.dart';
import 'package:app/features/expenses/domain/usecases/get_expense_detail.dart';
import 'package:app/features/expenses/domain/usecases/get_expenses.dart';
import 'package:app/features/expenses/domain/usecases/update_expense.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final supabaseExpenseDataSourceProvider = Provider<SupabaseExpenseDataSource>((
  ref,
) {
  return SupabaseExpenseDataSource(ref.watch(supabaseClientProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(ref.watch(supabaseExpenseDataSourceProvider));
});

// Use cases
final createExpenseUseCaseProvider = Provider<CreateExpense>((ref) {
  return CreateExpense(ref.watch(expenseRepositoryProvider));
});

final getExpensesUseCaseProvider = Provider<GetExpenses>((ref) {
  return GetExpenses(ref.watch(expenseRepositoryProvider));
});

final getExpenseDetailUseCaseProvider = Provider<GetExpenseDetail>((ref) {
  return GetExpenseDetail(ref.watch(expenseRepositoryProvider));
});

final updateExpenseUseCaseProvider = Provider<UpdateExpense>((ref) {
  return UpdateExpense(ref.watch(expenseRepositoryProvider));
});

final deleteExpenseUseCaseProvider = Provider<DeleteExpense>((ref) {
  return DeleteExpense(ref.watch(expenseRepositoryProvider));
});

// Presentation providers
final expensesProvider = FutureProvider.family<List<ExpenseEntity>, String>((
  ref,
  groupId,
) async {
  final getExpenses = ref.watch(getExpensesUseCaseProvider);
  final result = await getExpenses(groupId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (expenses) => expenses,
  );
});

final expenseDetailProvider = FutureProvider.family<ExpenseEntity, String>((
  ref,
  expenseId,
) async {
  final getExpenseDetail = ref.watch(getExpenseDetailUseCaseProvider);
  final result = await getExpenseDetail(expenseId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (expense) => expense,
  );
});

/// Derives expense detail from the already-live [expensesProvider].
///
/// Since [expensesProvider] is invalidated directly by the realtime callback
/// (and this is proven to work for the list screen), watching it here gives
/// the detail screen automatic updates with zero extra plumbing.
///
/// Falls back to a direct API call if the expense isn't found in the list
/// (e.g. navigated via deep link before the list loaded).
final expenseDetailLiveProvider = FutureProvider.family<ExpenseEntity,
    ({String groupId, String expenseId})>((ref, params) async {
  // This creates a Riverpod dependency: when expensesProvider is invalidated
  // by the realtime callback, this provider automatically re-executes.
  final expensesAsync = ref.watch(expensesProvider(params.groupId));

  // Try to find the expense in the already-fetched list.
  final expenses = expensesAsync.valueOrNull;
  if (expenses != null) {
    final match = expenses.where((e) => e.id == params.expenseId);
    if (match.isNotEmpty) return match.first;
  }

  // Fallback: list not loaded yet or expense not found — fetch directly.
  final getExpenseDetail = ref.watch(getExpenseDetailUseCaseProvider);
  final result = await getExpenseDetail(params.expenseId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (expense) => expense,
  );
});
