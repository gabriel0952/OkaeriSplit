import 'package:app/core/errors/failures.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<AppResult<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppResult<UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppResult<void>> signOut();

  Future<AppResult<void>> deleteAccount();

  Future<AppResult<UserEntity?>> getCurrentUser();

  Stream<UserEntity?> authStateChanges();
}
