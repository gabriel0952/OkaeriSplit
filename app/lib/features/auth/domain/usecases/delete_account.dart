import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';

class DeleteAccount {
  const DeleteAccount(this._repository);
  final AuthRepository _repository;

  Future<AppResult<void>> call() => _repository.deleteAccount();
}
