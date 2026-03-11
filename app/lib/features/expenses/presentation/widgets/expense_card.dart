import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:app/features/expenses/presentation/widgets/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Task 2.3: Visual upgrade — category icon container, cleaner layout
class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    this.paidByName,
    this.onTap,
    this.customCategories = const [],
    this.showCard = true,
  });

  final ExpenseEntity expense;
  final String? paidByName;
  final VoidCallback? onTap;
  final List<GroupCategoryEntity> customCategories;
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Category icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIcon(expense.category, customCategories),
                color: colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Description + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${paidByName ?? expense.paidBy} · ${DateFormat('MM/dd').format(expense.expenseDate)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            Text(
              '${expense.currency} ${expense.amount.toStringAsFixed(expense.amount.truncateToDouble() == expense.amount ? 0 : 2)}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    if (!showCard) return content;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
