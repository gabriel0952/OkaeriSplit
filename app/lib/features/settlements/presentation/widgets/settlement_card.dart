import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SettlementCard extends StatelessWidget {
  const SettlementCard({super.key, required this.settlement});

  final SettlementEntity settlement;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.payments_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          '${settlement.fromUser} → ${settlement.toUser}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          dateFormat.format(settlement.settledAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${settlement.currency} ${settlement.amount.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}
