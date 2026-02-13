import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/groups/presentation/widgets/member_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate realtime subscription for group members
    ref.listen(realtimeGroupMembersProvider(groupId), (prev, next) {});

    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('群組詳情')),
      body: groupAsync.when(
        loading: () => const AppLoadingWidget(),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        data: (group) {
          final isOwner = currentUser?.id == group.createdBy;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Group info header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${group.type.label} · ${group.currency}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Invite code
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: group.inviteCode),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('邀請碼已複製')),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '邀請碼：${group.inviteCode}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.copy,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Members section
              Text(
                '成員',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const AppLoadingWidget(),
                error: (error, _) => AppErrorWidget(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(groupMembersProvider(groupId)),
                ),
                data: (members) => Card(
                  child: Column(
                    children: members
                        .map((member) => MemberAvatar(member: member))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Expenses entry
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('消費紀錄'),
                  subtitle: const Text('查看與管理群組消費'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/$groupId/expenses'),
                ),
              ),
              const SizedBox(height: 12),

              // Balances entry
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('帳務總覽'),
                  subtitle: const Text('查看欠款與結算'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/$groupId/balances'),
                ),
              ),
              const SizedBox(height: 24),

              // Leave group button
              if (!isOwner)
                OutlinedButton.icon(
                  onPressed: () => _handleLeaveGroup(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('退出群組'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLeaveGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認退出'),
        content: const Text('確定要退出這個群組嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final leaveGroup = ref.read(leaveGroupUseCaseProvider);
    final result = await leaveGroup(groupId);

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(groupsProvider);
        context.go('/groups');
      },
    );
  }
}
