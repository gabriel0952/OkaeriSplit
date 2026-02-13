import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/supabase_expense_datasource.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';
import 'package:fpdart/fpdart.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  const ExpenseRepositoryImpl(this._dataSource);
  final SupabaseExpenseDataSource _dataSource;

  @override
  Future<AppResult<List<ExpenseEntity>>> getExpenses(String groupId) async {
    try {
      final expenses = await _dataSource.getExpenses(groupId);
      return Right(expenses);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<ExpenseEntity>> getExpenseDetail(String expenseId) async {
    try {
      final expense = await _dataSource.getExpenseDetail(expenseId);
      return Right(expense);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<String>> createExpense({
    required String groupId,
    required String paidBy,
    required double amount,
    required String currency,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    required List<Map<String, dynamic>> splits,
  }) async {
    try {
      final expenseId = await _dataSource.createExpense(
        groupId: groupId,
        paidBy: paidBy,
        amount: amount,
        currency: currency,
        category: category,
        description: description,
        note: note,
        expenseDate: expenseDate,
        splits: splits,
      );
      return Right(expenseId);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> updateExpense({
    required String expenseId,
    required double amount,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
  }) async {
    try {
      await _dataSource.updateExpense(
        expenseId: expenseId,
        amount: amount,
        category: category,
        description: description,
        note: note,
        expenseDate: expenseDate,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> deleteExpense(String expenseId) async {
    try {
      await _dataSource.deleteExpense(expenseId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
