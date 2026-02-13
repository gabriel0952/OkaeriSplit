import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter/material.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member});

  final GroupMemberEntity member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = member.role == 'owner';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: member.avatarUrl != null
            ? NetworkImage(member.avatarUrl!)
            : null,
        child: member.avatarUrl == null
            ? Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
              )
            : null,
      ),
      title: Text(member.displayName),
      trailing: isOwner
          ? Chip(
              label: Text(
                '管理員',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              backgroundColor: theme.colorScheme.primaryContainer,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}
