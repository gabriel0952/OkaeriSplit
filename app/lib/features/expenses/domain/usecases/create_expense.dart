import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';

class CreateExpense {
  const CreateExpense(this._repository);
  final ExpenseRepository _repository;

  Future<AppResult<String>> call({
    required String groupId,
    required String paidBy,
    required double amount,
    required String currency,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    required List<Map<String, dynamic>> splits,
  }) {
    return _repository.createExpense(
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
  }
}
