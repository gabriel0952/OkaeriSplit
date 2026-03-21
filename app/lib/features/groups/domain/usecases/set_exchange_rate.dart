import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class SetExchangeRate {
  const SetExchangeRate(this._repository);
  final GroupRepository _repository;

  Future<AppResult<void>> call(String groupId, String currency, double rate) {
    return _repository.setExchangeRate(groupId, currency, rate);
  }
}
