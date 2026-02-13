import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class DebtRow extends StatelessWidget {
  const DebtRow({
    super.key,
    required this.balance,
    required this.currency,
    required this.isCurrentUser,
    this.onMarkSettled,
  });

  final BalanceEntity balance;
  final String currency;
  final bool isCurrentUser;
  final VoidCallback? onMarkSettled;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance.netBalance >= 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: balance.avatarUrl != null
            ? NetworkImage(balance.avatarUrl!)
            : null,
        child: balance.avatarUrl == null
            ? Text(balance.displayName.isNotEmpty
                ? balance.displayName[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(
        balance.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '已付 $currency ${balance.totalPaid.toStringAsFixed(0)} / '
        '應分攤 $currency ${balance.totalOwed.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isPositive ? '+' : ''}$currency ${balance.netBalance.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (isCurrentUser && !isPositive) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onMarkSettled,
              icon: const Icon(Icons.check_circle_outline),
              tooltip: '標記已付款',
              color: Theme.of(context).colorScheme.primary,
              iconSize: 20,
            ),
          ],
        ],
      ),
    );
  }
}
