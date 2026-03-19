import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

// Task 2.2: Semantic colors from design system
const _positiveColor = Color(0xFF16A34A);
const _positiveColorDark = Color(0xFF22C55E);
const _negativeColor = Color(0xFFDC2626);
const _negativeColorDark = Color(0xFFEF4444);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positiveColor = isDark ? _positiveColorDark : _positiveColor;
    final negativeColor = isDark ? _negativeColorDark : _negativeColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '個人帳務總覽',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  tooltip: '計算說明',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('帳務總覽說明'),
                        content: const Text(
                          '應收：各群組中別人欠你的金額之和\n'
                          '應付：各群組中你欠別人的金額之和\n'
                          '淨額：應收減去應付，正值代表整體為收款方',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryColumn(
                      label: '應收',
                      amount: totalReceivable,
                      color: positiveColor,
                      currency: currencyLabel,
                    ),
                  ),
                  VerticalDivider(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                  Expanded(
                    child: _SummaryColumn(
                      label: '應付',
                      amount: totalPayable,
                      color: negativeColor,
                      currency: currencyLabel,
                    ),
                  ),
                  VerticalDivider(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                  Expanded(
                    child: _SummaryColumn(
                      label: '淨額',
                      amount: net,
                      color: net >= 0 ? positiveColor : negativeColor,
                      currency: currencyLabel,
                    ),
                  ),
                ],
              ),
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
                fontWeight: FontWeight.w500,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$currency ${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
