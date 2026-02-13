import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';

abstract class ExpenseRepository {
  Future<AppResult<List<ExpenseEntity>>> getExpenses(String groupId);

  Future<AppResult<ExpenseEntity>> getExpenseDetail(String expenseId);

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
  });

  Future<AppResult<void>> updateExpense({
    required String expenseId,
    required double amount,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
  });

  Future<AppResult<void>> deleteExpense(String expenseId);
}
