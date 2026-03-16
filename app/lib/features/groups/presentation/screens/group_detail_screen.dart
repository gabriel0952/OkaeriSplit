import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/features/groups/presentation/widgets/add_guest_member_dialog.dart';
import 'package:app/features/groups/presentation/widgets/invite_member_dialog.dart';
import 'package:app/features/groups/presentation/widgets/member_avatar.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String get groupId => widget.groupId;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    // Activate realtime subscription for group members (skipped when offline).
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      ref.listen(realtimeGroupMembersProvider(groupId), (prev, next) {});
    }

    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = ref.watch(isGuestProvider);

    return PopScope(
      // Guests cannot pop back to the group list
      canPop: !isGuest,
      child: Scaffold(
      appBar: AppBar(
        // Hide the back button for guests (nothing useful to go back to)
        automaticallyImplyLeading: !isGuest,
        title: const Text('群組詳情'),
        actions: [
          if (isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('唯讀'),
                labelStyle: const TextStyle(fontSize: 12),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.visibility_outlined, size: 14),
              ),
            ),
          // Archived badge (shown in AppBar before group data loads via groupAsync)
          if (!isGuest)
            groupAsync.whenOrNull(
              data: (group) => group.isArchived
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Chip(
                        label: const Text('已封存'),
                        labelStyle: const TextStyle(fontSize: 12),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.archive_outlined, size: 14),
                      ),
                    )
                  : null,
            ) ?? const SizedBox.shrink(),
          // Share button (non-guest only)
          if (!isGuest)
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              tooltip: '分享群組',
              onPressed: _isSharing ? null : () => _handleShareLink(context),
            ),
        ],
      ),
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
                  // 6.3: Hide member add buttons for guests and archived groups
                  if (!isGuest && !group.isArchived) ...[
                    TextButton.icon(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => AddGuestMemberDialog(
                            groupId: groupId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('訪客'),
                    ),
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

              // Guest actions
              if (isGuest) ...[
                FilledButton.icon(
                  onPressed: () => context.push('/guest-upgrade'),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('建立正式帳號'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _handleGuestExit(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text('退出訪客模式'),
                ),
                const SizedBox(height: 8),
              ],

              // 5.2: Reopen button (owner only, archived groups)
              if (!isGuest && isOwner && group.isArchived) ...[
                OutlinedButton.icon(
                  onPressed: () => _handleReopenGroup(context, ref),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('重新開啟群組'),
                ),
                const SizedBox(height: 8),
              ],

              // 5.1: Archive button (owner only, active groups)
              if (!isGuest && isOwner && !group.isArchived) ...[
                Builder(builder: (context) {
                  final balancesAsync = ref.watch(balancesProvider(groupId));
                  final unsettled = balancesAsync.valueOrNull?.fold<double>(
                        0, (sum, b) => sum + (b.netBalance > 0 ? b.netBalance : 0),
                      ) ?? 0;
                  return OutlinedButton.icon(
                    onPressed: () => _handleArchiveGroup(context, ref, unsettled),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('封存群組'),
                  );
                }),
                const SizedBox(height: 8),
              ],

              // Leave / Delete group button (hidden for guests and archived groups)
              if (!isGuest && !group.isArchived)
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
    ), // Scaffold
    ); // PopScope
  }

  Future<void> _handleShareLink(BuildContext context) async {
    setState(() => _isSharing = true);
    final useCase = ref.read(createShareLinkUseCaseProvider);
    final result = await useCase(groupId);
    if (!mounted) return;
    setState(() => _isSharing = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失敗：${failure.message}')),
        );
      },
      (token) {
        final url = '${AppConstants.shareDomain}/s/$token';
        SharePlus.instance.share(ShareParams(text: url));
      },
    );
  }

  Future<void> _handleGuestExit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出訪客模式'),
        content: const Text('確定要退出訪客模式嗎？\n退出後可以用相同代碼重新進入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final signOut = ref.read(signOutUseCaseProvider);
    await signOut();
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

  Future<void> _handleArchiveGroup(
    BuildContext context,
    WidgetRef ref,
    double unsettled,
  ) async {
    // If there are unsettled amounts, warn first
    if (unsettled > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('仍有未結清欠款'),
          content: Text(
            '目前群組還有 ${unsettled.toStringAsFixed(0)} 元未結清。\n封存後群組將變為唯讀，無法繼續記帳或結算。\n\n確定仍要封存？',
          ),
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
              child: const Text('仍要封存'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('封存群組'),
          content: const Text('封存後群組將變為唯讀，所有成員無法繼續記帳。訪客帳號將被刪除。\n\n可隨時重新開啟群組。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('封存'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.functions.invoke(
        'archive_group',
        body: {'group_id': groupId},
      );
      if (!context.mounted) return;
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('群組已封存')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('封存失敗：$e')),
      );
    }
  }

  Future<void> _handleReopenGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新開啟群組'),
        content: const Text('重新開啟後，所有成員可以繼續記帳與結算。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新開啟'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.rpc('reopen_group', params: {'p_group_id': groupId});
      if (!context.mounted) return;
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('群組已重新開啟')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：$e')),
      );
    }
  }
}
