import 'package:app/core/errors/failures.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/domain/repositories/settlement_repository.dart';

class GetSettlements {
  const GetSettlements(this._repository);
  final SettlementRepository _repository;

  Future<AppResult<List<SettlementEntity>>> call(String groupId) {
    return _repository.getSettlements(groupId);
  }
}
