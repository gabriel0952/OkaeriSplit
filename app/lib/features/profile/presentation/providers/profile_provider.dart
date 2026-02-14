import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/profile/data/datasources/supabase_profile_datasource.dart';
import 'package:app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';
import 'package:app/features/profile/domain/usecases/get_profile.dart';
import 'package:app/features/profile/domain/usecases/update_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final supabaseProfileDataSourceProvider =
    Provider<SupabaseProfileDataSource>((ref) {
  return SupabaseProfileDataSource(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(supabaseProfileDataSourceProvider));
});

// Use cases
final getProfileUseCaseProvider = Provider<GetProfile>((ref) {
  return GetProfile(ref.watch(profileRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfile>((ref) {
  return UpdateProfile(ref.watch(profileRepositoryProvider));
});

// Presentation
final profileProvider = FutureProvider<UserEntity>((ref) async {
  final currentUser = ref.watch(authStateProvider).valueOrNull;
  if (currentUser == null) throw Exception('未登入');

  final getProfile = ref.watch(getProfileUseCaseProvider);
  final result = await getProfile(currentUser.id);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (profile) => profile,
  );
});
