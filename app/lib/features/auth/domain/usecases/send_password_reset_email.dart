import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';

class SendPasswordResetEmail {
  const SendPasswordResetEmail(this._repository);
  final AuthRepository _repository;

  Future<AppResult<void>> call(String email) {
    return _repository.sendPasswordResetEmail(email);
  }
}
