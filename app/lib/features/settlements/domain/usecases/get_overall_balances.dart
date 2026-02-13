import 'package:app/core/errors/failures.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/domain/repositories/settlement_repository.dart';

class GetOverallBalances {
  const GetOverallBalances(this._repository);
  final SettlementRepository _repository;

  Future<AppResult<List<OverallBalanceEntity>>> call(String userId) {
    return _repository.getOverallBalances(userId);
  }
}
