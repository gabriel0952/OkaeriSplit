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

  Future<AppResult<UserEntity>> upgradeGuestAccount({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppResult<void>> deleteAccount();

  Future<AppResult<void>> sendPasswordResetEmail(String email);

  Future<AppResult<void>> updatePassword(String newPassword);

  Future<AppResult<UserEntity?>> getCurrentUser();

  Stream<UserEntity?> authStateChanges();
}
