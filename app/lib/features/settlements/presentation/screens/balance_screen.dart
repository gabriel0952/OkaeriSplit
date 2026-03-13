import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/providers/realtime_provider.dart';
import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/empty_state_widget.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/groups/presentation/providers/group_provider.dart';
import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:app/features/settlements/presentation/widgets/balance_card.dart';
import 'package:app/features/settlements/presentation/widgets/debt_row.dart';
import 'package:app/features/settlements/presentation/widgets/simplified_debt_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BalanceScreen extends ConsumerWidget {
  const BalanceScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate realtime subscription for settlements & balances (online only)
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      ref.listen(realtimeSettlementsProvider(groupId), (prev, next) {});
    }

    final balancesAsync = ref.watch(balancesProvider(groupId));
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('帳務總覽'),
        actions: [
          IconButton(
            onPressed: () => context.push('/groups/$groupId/settlements'),
            icon: const Icon(Icons.history),
            tooltip: '結算歷史',
          ),
        ],
      ),
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
          final simplifiedDebts = ref.watch(simplifiedDebtsProvider(groupId));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(balancesProvider(groupId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BalanceCard(balances: balances, currency: currency),
                const SizedBox(height: 24),
                Text(
                  '建議轉帳',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: simplifiedDebts.map((debt) {
                            final isFromCurrentUser =
                                debt.fromUserId == currentUser?.id;
                            return SimplifiedDebtRow(
                              debt: debt,
                              currency: currency,
                              isFromCurrentUser: isFromCurrentUser,
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
                Text(
                  '成員明細',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: balances.map((balance) {
                      final isCurrentUser =
                          balance.userId == currentUser?.id;
                      return DebtRow(
                        balance: balance,
                        currency: currency,
                        isCurrentUser: isCurrentUser,
                      );
                    }).toList(),
                  ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (_) {
        ref.invalidate(balancesProvider(groupId));
        ref.invalidate(settlementsProvider(groupId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已標記付款成功')),
        );
      },
    );
  }
}
