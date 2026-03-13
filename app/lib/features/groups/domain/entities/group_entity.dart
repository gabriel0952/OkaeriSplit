import 'package:app/core/constants/app_constants.dart';

class GroupEntity {
  const GroupEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final GroupType type;
  final String currency;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
}

class GroupMemberEntity {
  const GroupMemberEntity({
    required this.groupId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.isGuest = false,
  });

  final String groupId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;
  final bool isGuest;
}
