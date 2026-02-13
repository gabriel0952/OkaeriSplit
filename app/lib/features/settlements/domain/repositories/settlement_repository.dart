import 'package:app/core/errors/failures.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';

abstract class SettlementRepository {
  Future<AppResult<List<BalanceEntity>>> getBalances(String groupId);

  Future<AppResult<List<OverallBalanceEntity>>> getOverallBalances(
    String userId,
  );

  Future<AppResult<List<SettlementEntity>>> getSettlements(String groupId);

  Future<AppResult<String>> markSettled({
    required String groupId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String currency,
  });
}
