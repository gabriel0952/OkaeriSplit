import 'package:app/features/profile/domain/entities/payment_info_entity.dart';

class UserEntity {
  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.defaultCurrency = 'TWD',
    this.isGuest = false,
    this.paymentInfo,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String defaultCurrency;
  final bool isGuest;
  final PaymentInfoEntity? paymentInfo;
}
