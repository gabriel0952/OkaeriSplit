import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/repositories/expense_repository.dart';

class GetExpenses {
  const GetExpenses(this._repository);
  final ExpenseRepository _repository;

  Future<AppResult<List<ExpenseEntity>>> call(String groupId) {
    return _repository.getExpenses(groupId);
  }
}
