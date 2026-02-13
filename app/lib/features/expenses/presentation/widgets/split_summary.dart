import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter/material.dart';

class SplitSummary extends StatelessWidget {
  const SplitSummary({
    super.key,
    required this.splits,
    required this.members,
    required this.currency,
  });

  final List<ExpenseSplitEntity> splits;
  final List<GroupMemberEntity> members;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: splits.map((split) {
        final member = members
            .where((m) => m.userId == split.userId)
            .firstOrNull;
        final name = member?.displayName ?? split.userId;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name)),
              Text(
                '\$${split.amount.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
