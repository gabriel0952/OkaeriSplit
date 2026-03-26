import 'package:app/core/errors/failures.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';

class GetPaymentInfo {
  const GetPaymentInfo(this._repository);
  final ProfileRepository _repository;

  Future<AppResult<PaymentInfoEntity?>> call(String userId) {
    return _repository.getPaymentInfo(userId);
  }
}
