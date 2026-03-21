import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/groups/presentation/widgets/add_guest_member_dialog.dart';
import 'package:app/features/groups/presentation/widgets/invite_member_dialog.dart';
import 'package:app/features/groups/presentation/widgets/member_avatar.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/utils/resolve_display_name.dart';
import 'package:go_router/go_router.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  String get groupId => widget.groupId;

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('群組設定')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: groupAsync.when(
              loading: () => const AppLoadingWidget(),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(groupDetailProvider(groupId)),
              ),
              data: (group) {
                final isOwner = currentUser?.id == group.createdBy;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── 成員 Section ───────────────────────────────────
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
                        onRetry: () =>
                            ref.invalidate(groupMembersProvider(groupId)),
                      ),
                      data: (members) => Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: members.map((member) {
                            final resolvedName =
                                resolveDisplayName(members, member);
                            final canRemove = isOwner &&
                                !group.isArchived &&
                                member.userId != currentUser?.id &&
                                member.role != 'owner';

                            final tile = MemberAvatar(
                              member: member,
                              resolvedName: resolvedName,
                            );

                            if (!canRemove) return tile;

                            return Dismissible(
                              key: Key(member.userId),
                              direction: DismissDirection.endToStart,
                              background: ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.person_remove_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                              ),
                              confirmDismiss: (_) => _tryRemoveMember(
                                context,
                                member.userId,
                                resolvedName,
                              ),
                              child: tile,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── 功能入口 Section ───────────────────────────────
                    Text(
                      '功能',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                                Icons.account_balance_wallet_outlined),
                            title: const Text('帳務總覽'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/groups/$groupId/balances'),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.pie_chart_outline),
                            title: const Text('消費統計'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/groups/$groupId/stats'),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading:
                                const Icon(Icons.history_outlined),
                            title: const Text('結算紀錄'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/groups/$groupId/settlements'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Guest 操作區 ────────────────────────────────────
                    if (isGuest) ...[
                      FilledButton.icon(
                        onPressed: () => context.push('/guest-upgrade'),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('建立正式帳號'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _handleGuestExit(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('退出訪客模式'),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── 危險操作區 ──────────────────────────────────────
                    if (!isGuest) ...[
                      if (isOwner && group.isArchived) ...[
                        OutlinedButton.icon(
                          onPressed: () => _handleReopenGroup(context),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('重新開啟群組'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (isOwner && !group.isArchived) ...[
                        Builder(builder: (context) {
                          final balancesAsync =
                              ref.watch(balancesProvider(groupId));
                          final unsettled =
                              balancesAsync.valueOrNull?.fold<double>(
                                    0,
                                    (sum, b) => sum +
                                        (b.netBalance > 0 ? b.netBalance : 0),
                                  ) ??
                                  0;
                          return OutlinedButton.icon(
                            onPressed: () =>
                                _handleArchiveGroup(context, unsettled),
                            icon: const Icon(Icons.archive_outlined),
                            label: const Text('封存群組'),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                      if (!group.isArchived)
                        if (isOwner)
                          OutlinedButton.icon(
                            onPressed: () => _handleDeleteGroup(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('刪除群組'),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () => _handleLeaveGroup(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('退出群組'),
                          ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _tryRemoveMember(
    BuildContext context,
    String userId,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除成員'),
        content: Text('確定要將「$displayName」從群組中移除嗎？'),
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
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    final removeMember = ref.read(removeMemberUseCaseProvider);
    final result =
        await removeMember(groupId: groupId, userId: userId);

    if (!context.mounted) return false;

    return result.fold(
      (failure) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
            title: const Text('無法移除成員'),
            content: Text(_friendlyRemoveError(failure.message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return false;
      },
      (_) {
        ref.invalidate(groupMembersProvider(groupId));
        return true;
      },
    );
  }

  String _friendlyRemoveError(String raw) {
    if (raw.contains('尚有未結清帳款')) {
      final match = RegExp(r'淨額\s*([\d.+-]+)').firstMatch(raw);
      if (match != null) {
        return '「此成員」尚有未結清帳款（淨額 ${match.group(1)}），\n請先在帳務總覽中完成結算，再移除此成員。';
      }
      return '此成員尚有未結清帳款，\n請先完成結算後再移除。';
    }
    if (raw.contains('只有管理員')) return '只有群組管理員可以移除成員。';
    if (raw.contains('無法移除管理員')) return '無法移除群組管理員。';
    return '移除成員時發生錯誤，請稍後再試。';
  }

  Future<void> _handleGuestExit(BuildContext context) async {
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

  Future<void> _handleDeleteGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除群組'),
        content: const Text(
            '確定要刪除這個群組嗎？所有消費紀錄、帳務與成員資料都將被永久刪除，此操作無法復原。'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(groupsProvider);
        context.go('/groups');
      },
    );
  }

  Future<void> _handleLeaveGroup(BuildContext context) async {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(groupsProvider);
        context.go('/groups');
      },
    );
  }

  Future<void> _handleArchiveGroup(
      BuildContext context, double unsettled) async {
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
          content: const Text(
              '封存後群組將變為唯讀，所有成員無法繼續記帳。訪客帳號將被刪除。\n\n可隨時重新開啟群組。'),
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

  Future<void> _handleReopenGroup(BuildContext context) async {
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
