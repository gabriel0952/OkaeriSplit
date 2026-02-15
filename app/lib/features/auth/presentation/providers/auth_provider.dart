import 'package:app/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/get_current_user.dart';
import 'package:app/features/auth/domain/usecases/sign_in.dart';
import 'package:app/features/auth/domain/usecases/sign_out.dart';
import 'package:app/features/auth/domain/usecases/delete_account.dart';
import 'package:app/features/auth/domain/usecases/sign_up.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Infrastructure
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(supabaseAuthDataSourceProvider));
});

// Use cases
final signInUseCaseProvider = Provider<SignIn>((ref) {
  return SignIn(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUp>((ref) {
  return SignUp(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});

final deleteAccountUseCaseProvider = Provider<DeleteAccount>((ref) {
  return DeleteAccount(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUser>((ref) {
  return GetCurrentUser(ref.watch(authRepositoryProvider));
});

// Auth state stream
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

// Sign-in action
final signInActionProvider =
    FutureProvider.family<UserEntity, ({String email, String password})>((
      ref,
      params,
    ) async {
      final signIn = ref.watch(signInUseCaseProvider);
      final result = await signIn(
        email: params.email,
        password: params.password,
      );
      return result.fold(
        (failure) => throw Exception(failure.message),
        (user) => user,
      );
    });
