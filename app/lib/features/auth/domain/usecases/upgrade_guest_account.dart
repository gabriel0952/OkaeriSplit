import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';

class UpgradeGuestAccount {
  const UpgradeGuestAccount(this._repository);
  final AuthRepository _repository;

  Future<AppResult<UserEntity>> call({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repository.upgradeGuestAccount(
      email: email,
      password: password,
      displayName: displayName,
    );
  }
}
