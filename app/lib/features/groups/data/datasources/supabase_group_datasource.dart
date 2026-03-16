import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseGroupDataSource {
  const SupabaseGroupDataSource(this._client);
  final SupabaseClient _client;

  Future<List<GroupEntity>> getGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await _client
        .from('group_members')
        .select('*, groups(*)')
        .eq('user_id', userId);

    return (response as List).map((row) {
      final group = row['groups'] as Map<String, dynamic>;
      return _mapGroup(group);
    }).toList();
  }

  Future<GroupEntity> getGroupDetail(String groupId) async {
    final response = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .single();
    return _mapGroup(response);
  }

  Future<String> createGroup({
    required String name,
    required String type,
    required String currency,
  }) async {
    final response = await _client.rpc(
      'create_group',
      params: {'p_name': name, 'p_type': type, 'p_currency': currency},
    );
    return response as String;
  }

  Future<String> joinGroupByCode(String inviteCode) async {
    final response = await _client.rpc(
      'join_group_by_code',
      params: {'p_invite_code': inviteCode},
    );
    return response as String;
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('使用者未登入');
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<List<GroupMemberEntity>> getGroupMembers(String groupId) async {
    final response = await _client
        .from('group_members')
        .select('*, profiles(id, display_name, email, avatar_url, is_guest)')
        .eq('group_id', groupId);

    return (response as List).map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      return GroupMemberEntity(
        groupId: row['group_id'] as String,
        userId: row['user_id'] as String,
        displayName:
            profile?['display_name'] as String? ??
            profile?['email'] as String? ??
            '',
        avatarUrl: profile?['avatar_url'] as String?,
        role: row['role'] as String? ?? 'member',
        joinedAt: DateTime.parse(row['joined_at'] as String),
        isGuest: profile?['is_guest'] as bool? ?? false,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final currentUserId = _client.auth.currentUser?.id ?? '';
    final response = await _client
        .from('profiles')
        .select('id, email, display_name, avatar_url')
        .or('email.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', currentUserId)
        .eq('is_guest', false)
        .limit(20);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> inviteUserToGroup({
    required String groupId,
    required String userId,
  }) async {
    await _client.rpc(
      'invite_user_to_group',
      params: {'p_group_id': groupId, 'p_user_id': userId},
    );
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.rpc(
      'delete_group',
      params: {'p_group_id': groupId},
    );
  }

  Future<String> createShareLink(String groupId) async {
    final response = await _client.rpc(
      'create_share_link',
      params: {'p_group_id': groupId},
    );
    return response as String;
  }

  GroupEntity _mapGroup(Map<String, dynamic> data) {
    return GroupEntity(
      id: data['id'] as String,
      name: data['name'] as String,
      type: GroupType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => GroupType.other,
      ),
      currency: data['currency'] as String? ?? 'TWD',
      inviteCode: data['invite_code'] as String? ?? '',
      createdBy: data['created_by'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      status: data['status'] as String? ?? 'active',
    );
  }
}
