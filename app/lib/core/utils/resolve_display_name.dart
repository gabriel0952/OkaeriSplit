import 'package:app/features/groups/domain/entities/group_entity.dart';

/// Returns [member]'s display name, appending a short email prefix in
/// parentheses when another member in [members] shares the exact same name.
String resolveDisplayName(
  List<GroupMemberEntity> members,
  GroupMemberEntity member,
) {
  final hasDuplicate = members.any(
    (m) => m.userId != member.userId && m.displayName == member.displayName,
  );
  if (!hasDuplicate) return member.displayName;

  final email = member.email;
  if (email == null || email.isEmpty) return member.displayName;

  final atIndex = email.indexOf('@');
  final prefix = atIndex > 0 ? email.substring(0, atIndex) : email;
  final short = prefix.length > 8 ? prefix.substring(0, 8) : prefix;
  return '${member.displayName} ($short)';
}

/// Builds a map of userId → resolved display name for a list of members.
Map<String, String> buildResolvedMemberMap(List<GroupMemberEntity> members) {
  return {
    for (final m in members) m.userId: resolveDisplayName(members, m),
  };
}
