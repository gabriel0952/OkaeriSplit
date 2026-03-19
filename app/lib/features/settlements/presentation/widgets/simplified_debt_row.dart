import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class SimplifiedDebtRow extends StatelessWidget {
  const SimplifiedDebtRow({
    super.key,
    required this.debt,
    required this.currency,
    required this.canPay,
    this.fromName,
    this.toName,
    this.onPay,
  });

  final SimplifiedDebtEntity debt;
  final String currency;
  /// True when the current user is either the payer or the payee.
  final bool canPay;
  /// Resolved display name override for the from-user (disambiguation).
  final String? fromName;
  /// Resolved display name override for the to-user (disambiguation).
  final String? toName;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final resolvedFrom = fromName ?? debt.fromDisplayName;
    final resolvedTo = toName ?? debt.toDisplayName;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: debt.fromAvatarUrl != null
            ? NetworkImage(debt.fromAvatarUrl!)
            : null,
        child: debt.fromAvatarUrl == null
            ? Text(resolvedFrom.isNotEmpty
                ? resolvedFrom[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(
        '$resolvedFrom → $resolvedTo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '$currency ${debt.amount.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
      ),
      trailing: canPay
          ? FilledButton.tonal(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('付款'),
            )
          : null,
    );
  }
}
