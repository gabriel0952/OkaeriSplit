import 'package:app/core/errors/failures.dart';
import 'package:app/features/groups/domain/entities/group_exchange_rate_entity.dart';
import 'package:app/features/groups/domain/repositories/group_repository.dart';

class GetExchangeRates {
  const GetExchangeRates(this._repository);
  final GroupRepository _repository;

  Future<AppResult<List<GroupExchangeRateEntity>>> call(String groupId) {
    return _repository.getExchangeRates(groupId);
  }
}
