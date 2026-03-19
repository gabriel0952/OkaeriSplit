import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/skeleton_box.dart';
import 'package:app/core/widgets/offline_banner.dart';
import 'package:app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:app/features/dashboard/presentation/widgets/balance_summary_card.dart';
import 'package:app/features/dashboard/presentation/widgets/group_balance_row.dart';
import 'package:app/features/dashboard/presentation/widgets/recent_expense_list.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void _showBalanceInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('帳務總覽說明'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(
            label: '應收',
            description: '各群組中別人欠你的金額之和',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: '應付',
            description: '各群組中你欠別人的金額之和',
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: '淨額',
            description: '應收減去應付，正值代表整體為收款方',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.description,
    required this.color,
  });

  final String label;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallAsync = ref.watch(overallBalancesProvider);
    final recentAsync = ref.watch(recentExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('總覽')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overallBalancesProvider);
          ref.invalidate(recentExpensesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance summary
            overallAsync.when(
              loading: () => const BalanceSkeleton(),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(overallBalancesProvider),
              ),
              data: (balances) {
                if (balances.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('加入群組後即可查看帳務')),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '個人帳務總覽',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          tooltip: '計算說明',
                          onPressed: () => _showBalanceInfo(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BalanceSummaryCard(balances: balances),
                    const SizedBox(height: 24),
                    Text(
                      '各群組帳務',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: balances
                            .map((balance) => GroupBalanceRow(
                                  balance: balance,
                                  onTap: () => context.push(
                                    '/groups/${balance.groupId}/balances',
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Recent expenses
            Text(
              '最近消費',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            recentAsync.when(
              loading: () => const ExpenseListSkeleton(),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(recentExpensesProvider),
              ),
              data: (expenses) => RecentExpenseList(expenses: expenses),
            ),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}
