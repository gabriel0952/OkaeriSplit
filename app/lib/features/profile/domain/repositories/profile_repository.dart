import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';

abstract class ProfileRepository {
  Future<AppResult<UserEntity>> getProfile(String userId);

  Future<AppResult<UserEntity>> updateProfile(
    String userId, {
    String? displayName,
    String? defaultCurrency,
  });

  Future<AppResult<PaymentInfoEntity?>> getPaymentInfo(String userId);

  Future<AppResult<void>> updatePaymentInfo(
    String userId,
    PaymentInfoEntity? paymentInfo,
  );
}
