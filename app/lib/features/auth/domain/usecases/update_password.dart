import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';

class UpdatePassword {
  const UpdatePassword(this._repository);
  final AuthRepository _repository;

  Future<AppResult<void>> call(String newPassword) {
    return _repository.updatePassword(newPassword);
  }
}
