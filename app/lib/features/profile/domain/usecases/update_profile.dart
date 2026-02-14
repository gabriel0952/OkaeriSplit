import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfile {
  const UpdateProfile(this._repository);
  final ProfileRepository _repository;

  Future<AppResult<UserEntity>> call({
    required String userId,
    String? displayName,
    String? defaultCurrency,
  }) {
    return _repository.updateProfile(
      userId,
      displayName: displayName,
      defaultCurrency: defaultCurrency,
    );
  }
}
