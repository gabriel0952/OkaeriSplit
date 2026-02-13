import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';

class UpdateExpense {
  const UpdateExpense(this._repository);
  final ExpenseRepository _repository;

  Future<AppResult<void>> call({
    required String expenseId,
    required double amount,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    List<Map<String, dynamic>>? splits,
  }) {
    return _repository.updateExpense(
      expenseId: expenseId,
      amount: amount,
      category: category,
      description: description,
      note: note,
      expenseDate: expenseDate,
      splits: splits,
    );
  }
}
