import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecentExpenseList extends StatelessWidget {
  const RecentExpenseList({super.key, required this.expenses});

  final List<ExpenseEntity> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('目前沒有消費紀錄')),
      );
    }

    final dateFormat = DateFormat('MM/dd');

    return Card(
      child: Column(
        children: expenses.map((expense) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.tertiaryContainer,
              child: Icon(
                _categoryIcon(expense.category),
                color:
                    Theme.of(context).colorScheme.onTertiaryContainer,
                size: 20,
              ),
            ),
            title: Text(
              expense.description,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              dateFormat.format(expense.expenseDate),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Text(
              '${expense.currency} ${expense.amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _categoryIcon(dynamic category) {
    final name = category.toString().split('.').last;
    switch (name) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'accommodation':
        return Icons.hotel;
      case 'entertainment':
        return Icons.movie;
      case 'dailyNecessities':
        return Icons.shopping_bag;
      default:
        return Icons.receipt;
    }
  }
}
