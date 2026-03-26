import 'package:app/core/errors/failures.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';

class UpdatePaymentInfo {
  const UpdatePaymentInfo(this._repository);
  final ProfileRepository _repository;

  Future<AppResult<void>> call(String userId, PaymentInfoEntity? paymentInfo) {
    return _repository.updatePaymentInfo(userId, paymentInfo);
  }
}
