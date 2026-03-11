import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class SimplifiedDebtRow extends StatelessWidget {
  const SimplifiedDebtRow({
    super.key,
    required this.debt,
    required this.currency,
    required this.isFromCurrentUser,
    this.onPay,
  });

  final SimplifiedDebtEntity debt;
  final String currency;
  final bool isFromCurrentUser;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: debt.fromAvatarUrl != null
            ? NetworkImage(debt.fromAvatarUrl!)
            : null,
        child: debt.fromAvatarUrl == null
            ? Text(debt.fromDisplayName.isNotEmpty
                ? debt.fromDisplayName[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(
        '${debt.fromDisplayName} → ${debt.toDisplayName}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '$currency ${debt.amount.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
      ),
      trailing: isFromCurrentUser
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
