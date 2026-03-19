import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/services/sync_service.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/data/datasources/hive_expense_datasource.dart';
import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/data/pending_expense_repository.dart';
import 'package:app/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
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

final hiveExpenseDataSourceProvider = Provider<HiveExpenseDataSource>((ref) {
  return HiveExpenseDataSource();
});

final pendingExpenseRepositoryProvider =
    Provider<PendingExpenseRepository>((ref) {
  return PendingExpenseRepository();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(pendingExpenseRepositoryProvider),
    ref.watch(supabaseExpenseDataSourceProvider),
    ref,
  );
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  return ExpenseRepositoryImpl(
    ref.watch(supabaseExpenseDataSourceProvider),
    ref.watch(hiveExpenseDataSourceProvider),
    ref.watch(pendingExpenseRepositoryProvider),
    isOnline,
  );
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
  // Re-fetch automatically when the logged-in user changes.
  final currentUser = ref.watch(authStateProvider).valueOrNull;
  if (currentUser == null) return [];

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
final expenseDetailLiveProvider = FutureProvider.family<ExpenseEntity,
    ({String groupId, String expenseId})>((ref, params) async {
  final expensesAsync = ref.watch(expensesProvider(params.groupId));

  final expenses = expensesAsync.valueOrNull;
  if (expenses != null) {
    final match = expenses.where((e) => e.id == params.expenseId);
    if (match.isNotEmpty) return match.first;
  }

  final getExpenseDetail = ref.watch(getExpenseDetailUseCaseProvider);
  final result = await getExpenseDetail(params.expenseId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (expense) => expense,
  );
});

// Group custom categories
final groupCategoriesProvider =
    FutureProvider.family<List<GroupCategoryEntity>, String>((
  ref,
  groupId,
) async {
  final isOnline = ref.watch(isOnlineProvider);
  if (!isOnline) return [];
  try {
    final ds = ref.watch(supabaseExpenseDataSourceProvider);
    return ds.getGroupCategories(groupId);
  } catch (_) {
    return [];
  }
});

/// Number of pending (offline) expenses waiting to sync.
final pendingCountProvider = Provider<int>((ref) {
  final repo = ref.watch(pendingExpenseRepositoryProvider);
  // Re-evaluate when connectivity changes (flush may have cleared items).
  ref.watch(connectivityProvider);
  return repo.count();
});
