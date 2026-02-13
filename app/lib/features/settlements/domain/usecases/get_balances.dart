import 'package:app/core/errors/failures.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/domain/repositories/settlement_repository.dart';

class GetBalances {
  const GetBalances(this._repository);
  final SettlementRepository _repository;

  Future<AppResult<List<BalanceEntity>>> call(String groupId) {
    return _repository.getBalances(groupId);
  }
}
