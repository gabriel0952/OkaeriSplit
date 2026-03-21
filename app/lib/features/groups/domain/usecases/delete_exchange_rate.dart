import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class DeleteExchangeRate {
  const DeleteExchangeRate(this._repository);
  final GroupRepository _repository;

  Future<AppResult<void>> call(String groupId, String currency) {
    return _repository.deleteExchangeRate(groupId, currency);
  }
}
