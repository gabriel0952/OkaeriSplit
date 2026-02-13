import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    this.paidByName,
    this.onTap,
  });

  final ExpenseEntity expense;
  final String? paidByName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            _categoryIcon(expense.category),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          expense.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${paidByName ?? expense.paidBy} · ${DateFormat('MM/dd').format(expense.expenseDate)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '\$${expense.amount.toStringAsFixed(expense.amount.truncateToDouble() == expense.amount ? 0 : 2)}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }

  static IconData _categoryIcon(ExpenseCategory category) {
    return switch (category) {
      ExpenseCategory.food => Icons.restaurant,
      ExpenseCategory.transport => Icons.directions_car,
      ExpenseCategory.accommodation => Icons.hotel,
      ExpenseCategory.entertainment => Icons.movie,
      ExpenseCategory.dailyNecessities => Icons.shopping_bag,
      ExpenseCategory.other => Icons.receipt,
    };
  }
}
