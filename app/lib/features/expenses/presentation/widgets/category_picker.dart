import 'package:app/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ExpenseCategory selected;
  final ValueChanged<ExpenseCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.values.map((category) {
        final isSelected = category == selected;
        return ChoiceChip(
          avatar: Icon(
            _categoryIcon(category),
            size: 18,
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          label: Text(category.label),
          selected: isSelected,
          onSelected: (_) => onSelected(category),
        );
      }).toList(),
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
