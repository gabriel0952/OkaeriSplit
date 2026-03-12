import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/groups/presentation/widgets/invite_member_dialog.dart';
import 'package:app/features/groups/presentation/widgets/member_avatar.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate realtime subscription for group members (skipped when offline).
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      ref.listen(realtimeGroupMembersProvider(groupId), (prev, next) {});
    }

    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('群組詳情')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: groupAsync.when(
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
              const SizedBox(height: 12),

              // Quick summary card
              Builder(builder: (context) {
                final expensesAsync = ref.watch(expensesProvider(groupId));
                final balancesAsync = ref.watch(balancesProvider(groupId));

                final totalExpenses = expensesAsync.valueOrNull?.fold<double>(
                      0,
                      (sum, e) => sum + e.amount,
                    ) ??
                    0;
                final unsettled = balancesAsync.valueOrNull?.fold<double>(
                      0,
                      (sum, b) =>
                          sum + (b.netBalance > 0 ? b.netBalance : 0),
                    ) ??
                    0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '總支出',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group.currency} ${totalExpenses.toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '未結算',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group.currency} ${unsettled.toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: unsettled > 0
                                          ? Theme.of(context)
                                              .colorScheme
                                              .error
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Members section
              Row(
                children: [
                  Text(
                    '成員',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      final memberIds = membersAsync.valueOrNull
                              ?.map((m) => m.userId)
                              .toSet() ??
                          {};
                      showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => InviteMemberDialog(
                          groupId: groupId,
                          existingMemberIds: memberIds,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('邀請'),
                  ),
                ],
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
              const SizedBox(height: 12),

              // Stats entry
              Card(
                child: ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('消費統計'),
                  subtitle: const Text('分類佔比與月度趨勢'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/groups/$groupId/stats'),
                ),
              ),
              const SizedBox(height: 24),

              // Leave / Delete group button
              if (isOwner)
                OutlinedButton.icon(
                  onPressed: () => _handleDeleteGroup(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除群組'),
                )
              else
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
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除群組'),
        content: const Text('確定要刪除這個群組嗎？所有消費紀錄、帳務與成員資料都將被永久刪除，此操作無法復原。'),
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
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final deleteGroup = ref.read(deleteGroupUseCaseProvider);
    final result = await deleteGroup(groupId);

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
