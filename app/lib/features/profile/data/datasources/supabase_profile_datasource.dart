import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileDataSource {
  const SupabaseProfileDataSource(this._client);
  final SupabaseClient _client;

  Future<UserEntity> getProfile(String userId) async {
    final response =
        await _client.from('profiles').select().eq('id', userId).single();
    return _mapProfile(response);
  }

  Future<UserEntity> updateProfile(
    String userId, {
    String? displayName,
    String? defaultCurrency,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (defaultCurrency != null) updates['default_currency'] = defaultCurrency;

    final response = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return _mapProfile(response);
  }

  UserEntity _mapProfile(Map<String, dynamic> data) {
    return UserEntity(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      defaultCurrency: data['default_currency'] as String? ?? 'TWD',
    );
  }
}
