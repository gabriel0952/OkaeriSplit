import 'dart:convert';

import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveGroupDataSource {
  Box get _groupsBox => Hive.box('groups_cache');
  Box get _membersBox => Hive.box('group_members_cache');

  static const _groupsKey = 'all_groups';

  Future<void> saveGroups(List<GroupEntity> groups) async {
    final json = jsonEncode(groups.map(_groupToJson).toList());
    await _groupsBox.put(_groupsKey, json);
  }

  List<GroupEntity> getGroups() {
    final raw = _groupsBox.get(_groupsKey) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => _groupFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveMembers(
    String groupId,
    List<GroupMemberEntity> members,
  ) async {
    final json = jsonEncode(members.map(_memberToJson).toList());
    await _membersBox.put(groupId, json);
  }

  List<GroupMemberEntity> getMembers(String groupId) {
    final raw = _membersBox.get(groupId) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _memberFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Serialization helpers ---

  Map<String, dynamic> _groupToJson(GroupEntity g) => {
        'id': g.id,
        'name': g.name,
        'type': g.type.name,
        'currency': g.currency,
        'invite_code': g.inviteCode,
        'created_by': g.createdBy,
        'created_at': g.createdAt.toIso8601String(),
      };

  GroupEntity _groupFromJson(Map<String, dynamic> j) => GroupEntity(
        id: j['id'] as String,
        name: j['name'] as String,
        type: GroupType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => GroupType.other,
        ),
        currency: j['currency'] as String? ?? 'TWD',
        inviteCode: j['invite_code'] as String? ?? '',
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> _memberToJson(GroupMemberEntity m) => {
        'group_id': m.groupId,
        'user_id': m.userId,
        'display_name': m.displayName,
        'email': m.email,
        'avatar_url': m.avatarUrl,
        'role': m.role,
        'joined_at': m.joinedAt.toIso8601String(),
      };

  GroupMemberEntity _memberFromJson(Map<String, dynamic> j) =>
      GroupMemberEntity(
        groupId: j['group_id'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        email: j['email'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        role: j['role'] as String? ?? 'member',
        joinedAt: DateTime.parse(j['joined_at'] as String),
      );
}
