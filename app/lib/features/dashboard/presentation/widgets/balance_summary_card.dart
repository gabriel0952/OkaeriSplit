import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({super.key, required this.balances});

  final List<OverallBalanceEntity> balances;

  @override
  Widget build(BuildContext context) {
    double totalReceivable = 0;
    double totalPayable = 0;

    for (final b in balances) {
      if (b.netBalance > 0) {
        totalReceivable += b.netBalance;
      } else {
        totalPayable += b.netBalance.abs();
      }
    }

    final net = totalReceivable - totalPayable;

    final currencies = balances.map((b) => b.currency).toSet();
    final currencyLabel = currencies.length == 1 ? currencies.first : '\$';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '個人帳務總覽',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryColumn(
                    label: '應收',
                    amount: totalReceivable,
                    color: Colors.green,
                    currency: currencyLabel,
                  ),
                ),
                Expanded(
                  child: _SummaryColumn(
                    label: '應付',
                    amount: totalPayable,
                    color: Colors.red,
                    currency: currencyLabel,
                  ),
                ),
                Expanded(
                  child: _SummaryColumn(
                    label: '淨額',
                    amount: net,
                    color: net >= 0 ? Colors.green : Colors.red,
                    currency: currencyLabel,
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

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.label,
    required this.amount,
    required this.color,
    required this.currency,
  });

  final String label;
  final double amount;
  final Color color;
  final String currency;

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
        Text(
          '$currency ${amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
