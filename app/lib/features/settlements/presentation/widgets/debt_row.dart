import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class DebtRow extends StatelessWidget {
  const DebtRow({
    super.key,
    required this.balance,
    required this.currency,
    required this.isCurrentUser,
    this.resolvedName,
  });

  final BalanceEntity balance;
  final String currency;
  final bool isCurrentUser;
  final String? resolvedName;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance.netBalance >= 0;
    final colorScheme = Theme.of(context).colorScheme;
    final name = resolvedName ?? balance.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: balance.avatarUrl != null
                    ? NetworkImage(balance.avatarUrl!)
                    : null,
                child: balance.avatarUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '你',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${isPositive ? '+' : ''}$currency ${balance.netBalance.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isPositive
                            ? colorScheme.primary
                            : colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AmountInfoChip(
                  label: '已付',
                  value: balance.totalPaid.toStringAsFixed(0),
                  foregroundColor: colorScheme.onPrimaryContainer,
                  backgroundColor: colorScheme.primaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountInfoChip(
                  label: '應分攤',
                  value: balance.totalOwed.toStringAsFixed(0),
                  foregroundColor: colorScheme.onTertiaryContainer,
                  backgroundColor: colorScheme.tertiaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountInfoChip extends StatelessWidget {
  const _AmountInfoChip({
    required this.label,
    required this.value,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
