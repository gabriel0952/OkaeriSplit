import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    this.paidByName,
    this.onTap,
    this.customCategories = const [],
  });

  final ExpenseEntity expense;
  final String? paidByName;
  final VoidCallback? onTap;
  final List<GroupCategoryEntity> customCategories;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            categoryIcon(expense.category, customCategories),
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
}
