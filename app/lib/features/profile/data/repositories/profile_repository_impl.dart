import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/profile/data/datasources/supabase_profile_datasource.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';
import 'package:fpdart/fpdart.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dataSource);
  final SupabaseProfileDataSource _dataSource;

  @override
  Future<AppResult<UserEntity>> getProfile(String userId) async {
    try {
      final profile = await _dataSource.getProfile(userId);
      return Right(profile);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<UserEntity>> updateProfile(
    String userId, {
    String? displayName,
    String? defaultCurrency,
  }) async {
    try {
      final profile = await _dataSource.updateProfile(
        userId,
        displayName: displayName,
        defaultCurrency: defaultCurrency,
      );
      return Right(profile);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<PaymentInfoEntity?>> getPaymentInfo(String userId) async {
    try {
      final info = await _dataSource.getPaymentInfo(userId);
      return Right(info);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<void>> updatePaymentInfo(
    String userId,
    PaymentInfoEntity? paymentInfo,
  ) async {
    try {
      await _dataSource.updatePaymentInfo(userId, paymentInfo);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
