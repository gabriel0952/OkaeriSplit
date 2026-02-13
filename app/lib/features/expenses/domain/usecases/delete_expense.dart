import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';

class DeleteExpense {
  const DeleteExpense(this._repository);
  final ExpenseRepository _repository;

  Future<AppResult<void>> call(String expenseId) {
    return _repository.deleteExpense(expenseId);
  }
}
