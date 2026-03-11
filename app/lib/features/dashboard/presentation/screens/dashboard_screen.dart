import 'package:app/core/widgets/app_error_widget.dart';
import 'package:app/core/widgets/app_loading_widget.dart';
import 'package:app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:app/features/dashboard/presentation/widgets/balance_summary_card.dart';
import 'package:app/features/dashboard/presentation/widgets/group_balance_row.dart';
import 'package:app/features/dashboard/presentation/widgets/recent_expense_list.dart';
import 'package:app/features/settlements/presentation/providers/settlement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallAsync = ref.watch(overallBalancesProvider);
    final recentAsync = ref.watch(recentExpensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('總覽')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overallBalancesProvider);
          ref.invalidate(recentExpensesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance summary
            overallAsync.when(
              loading: () => const AppLoadingWidget(),
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
              loading: () => const AppLoadingWidget(),
              error: (error, _) => AppErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(recentExpensesProvider),
              ),
              data: (expenses) => RecentExpenseList(expenses: expenses),
            ),
          ],
        ),
      ),
    );
  }
}
