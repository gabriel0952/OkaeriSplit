import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';

class GetExpenseDetail {
  const GetExpenseDetail(this._repository);
  final ExpenseRepository _repository;

  Future<AppResult<ExpenseEntity>> call(String expenseId) {
    return _repository.getExpenseDetail(expenseId);
  }
}
