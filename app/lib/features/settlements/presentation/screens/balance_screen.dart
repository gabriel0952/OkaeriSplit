import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/utils/resolve_display_name.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:app/features/settlements/presentation/widgets/balance_card.dart';
import 'package:app/features/settlements/presentation/widgets/debt_row.dart';
import 'package:app/features/settlements/presentation/widgets/settlement_card.dart';
import 'package:app/features/settlements/presentation/widgets/simplified_debt_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BalanceScreen extends ConsumerWidget {
  const BalanceScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      ref.listen(realtimeSettlementsProvider(groupId), (prev, next) {});
    }

    final balancesAsync = ref.watch(balancesProvider(groupId));
    final settlementsAsync = ref.watch(settlementsProvider(groupId));
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('帳務總覽')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: balancesAsync.when(
              loading: () => const BalanceSkeleton(),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(balancesProvider(groupId)),
              ),
              data: (balances) {
                if (balances.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    title: '帳目已清空',
                    subtitle: '群組內沒有未清的帳款',
                  );
                }

                final currency = groupAsync.valueOrNull?.currency ?? 'TWD';
                final simplifiedDebts = ref.watch(
                  simplifiedDebtsProvider(groupId),
                );
                final members = membersAsync.valueOrNull ?? [];
                final resolvedMap = buildResolvedMemberMap(members);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(balancesProvider(groupId));
                    ref.invalidate(settlementsProvider(groupId));
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      BalanceCard(
                        balances: balances,
                        currency: currency,
                        currentUserId: currentUser?.id,
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        title: '建議轉帳',
                        subtitle: '依目前未結清帳務整理出的建議付款方式',
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: simplifiedDebts.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    '已全部結清！',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: simplifiedDebts.map((debt) {
                                  final isParticipant =
                                      debt.fromUserId == currentUser?.id ||
                                      debt.toUserId == currentUser?.id;
                                  return SimplifiedDebtRow(
                                    debt: debt,
                                    currency: currency,
                                    canPay: isParticipant,
                                    fromName: resolvedMap[debt.fromUserId],
                                    toName: resolvedMap[debt.toUserId],
                                    onPay: isGuest
                                        ? null
                                        : () => _handlePay(
                                            context,
                                            ref,
                                            debt,
                                            currency,
                                          ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: '成員明細',
                        subtitle: '查看每位成員已付、應分攤與目前淨額',
                        actionIcon: Icons.info_outline_rounded,
                        onActionTap: () =>
                            _showBalanceExplanationDialog(context),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (int i = 0; i < balances.length; i++) ...[
                              DebtRow(
                                balance: balances[i],
                                currency: currency,
                                isCurrentUser:
                                    balances[i].userId == currentUser?.id,
                                resolvedName: resolvedMap[balances[i].userId],
                              ),
                              if (i < balances.length - 1)
                                const Divider(
                                  height: 1,
                                  indent: 60,
                                  endIndent: 16,
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        title: '結算紀錄',
                        subtitle: '成員中途回報的付款會直接顯示在這裡，避免只看淨額造成誤解',
                      ),
                      const SizedBox(height: 8),
                      settlementsAsync.when(
                        loading: () => const _InlineStateCard(
                          icon: Icons.history_outlined,
                          title: '載入結算紀錄中...',
                        ),
                        error: (error, _) => _InlineRetryCard(
                          message: '結算紀錄載入失敗',
                          onRetry: () =>
                              ref.invalidate(settlementsProvider(groupId)),
                        ),
                        data: (settlements) {
                          if (settlements.isEmpty) {
                            return const _InlineStateCard(
                              icon: Icons.handshake_outlined,
                              title: '尚無結算紀錄',
                              subtitle: '有人完成付款或回報後，會即時顯示在這裡',
                            );
                          }

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (
                                  int i = 0;
                                  i < settlements.length;
                                  i++
                                ) ...[
                                  SettlementCard(
                                    settlement: settlements[i],
                                    memberMap: resolvedMap,
                                  ),
                                  if (i < settlements.length - 1)
                                    const Divider(height: 1, indent: 72),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePay(
    BuildContext context,
    WidgetRef ref,
    SimplifiedDebtEntity debt,
    String currency,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認付款'),
        content: Text(
          '確定要標記 ${debt.fromDisplayName} 支付 '
          '$currency ${debt.amount.toStringAsFixed(0)} 給 '
          '${debt.toDisplayName} 嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確認'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final markSettled = ref.read(markSettledUseCaseProvider);
    final result = await markSettled(
      groupId: groupId,
      fromUser: debt.fromUserId,
      toUser: debt.toUserId,
      amount: debt.amount,
      currency: currency,
    );

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        ref.invalidate(balancesProvider(groupId));
        ref.invalidate(settlementsProvider(groupId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已標記付款成功')));
      },
    );
  }

  Future<void> _showBalanceExplanationDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('淨額說明'),
        content: const Text(
          '淨額 = 已付 - 應分攤。若顯示為 0，代表這位成員目前剛好平衡，不一定是計算錯誤；中途回報的付款則會記錄在下方結算紀錄。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionIcon,
    this.onActionTap,
  });

  final String title;
  final String subtitle;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (actionIcon != null && onActionTap != null)
              IconButton(
                onPressed: onActionTap,
                icon: Icon(actionIcon, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: '查看說明',
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InlineStateCard extends StatelessWidget {
  const _InlineStateCard({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineRetryCard extends StatelessWidget {
  const _InlineRetryCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}

class BalanceSkeleton extends StatelessWidget {
  const BalanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(width: double.infinity, height: 140),
        SizedBox(height: 24),
        SkeletonBox(width: double.infinity, height: 220),
        SizedBox(height: 24),
        SkeletonBox(width: double.infinity, height: 260),
        SizedBox(height: 24),
        SkeletonBox(width: double.infinity, height: 180),
      ],
    );
  }
}
