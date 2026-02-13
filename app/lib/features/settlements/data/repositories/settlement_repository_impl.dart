import 'package:app/core/errors/failures.dart';
import 'package:app/features/settlements/data/datasources/supabase_settlement_datasource.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/domain/repositories/settlement_repository.dart';
import 'package:fpdart/fpdart.dart';

class SettlementRepositoryImpl implements SettlementRepository {
  const SettlementRepositoryImpl(this._dataSource);
  final SupabaseSettlementDataSource _dataSource;

  @override
  Future<AppResult<List<BalanceEntity>>> getBalances(String groupId) async {
    try {
      final balances = await _dataSource.getBalances(groupId);
      return Right(balances);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<OverallBalanceEntity>>> getOverallBalances(
    String userId,
  ) async {
    try {
      final balances = await _dataSource.getOverallBalances(userId);
      return Right(balances);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<SettlementEntity>>> getSettlements(
    String groupId,
  ) async {
    try {
      final settlements = await _dataSource.getSettlements(groupId);
      return Right(settlements);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<String>> markSettled({
    required String groupId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String currency,
  }) async {
    try {
      final id = await _dataSource.markSettled(
        groupId: groupId,
        fromUser: fromUser,
        toUser: toUser,
        amount: amount,
        currency: currency,
      );
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
