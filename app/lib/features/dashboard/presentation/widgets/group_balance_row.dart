import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';

class GroupBalanceRow extends StatelessWidget {
  const GroupBalanceRow({super.key, required this.balance, this.onTap});

  final OverallBalanceEntity balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance.netBalance >= 0;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          Icons.group_outlined,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        balance.groupName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${balance.currency} ${balance.netBalance.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
