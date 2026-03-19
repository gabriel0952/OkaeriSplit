import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balances,
    required this.currency,
    this.currentUserId,
  });

  final List<BalanceEntity> balances;
  final String currency;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    // Show only the current user's balance to avoid zero-sum artifacts
    final myBalance = currentUserId != null
        ? balances.where((b) => b.userId == currentUserId).firstOrNull
        : null;

    final double totalReceivable =
        myBalance != null && myBalance.netBalance > 0
            ? myBalance.netBalance
            : 0;
    final double totalPayable =
        myBalance != null && myBalance.netBalance < 0
            ? myBalance.netBalance.abs()
            : 0;

    final net = totalReceivable - totalPayable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '帳務摘要',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: '應收',
                    amount: totalReceivable,
                    currency: currency,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '應付',
                    amount: totalPayable,
                    currency: currency,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '淨額',
                    amount: net,
                    currency: currency,
                    color: net >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$currency ${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}
