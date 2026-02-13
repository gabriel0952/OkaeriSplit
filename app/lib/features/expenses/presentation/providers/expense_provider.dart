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
