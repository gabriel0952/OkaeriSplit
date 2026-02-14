import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:app/features/expenses/presentation/widgets/icon_picker_dialog.dart';
import 'package:flutter/material.dart';

/// Built-in category definitions (key → icon).
const _builtInIcons = <String, IconData>{
  'food': Icons.restaurant,
  'transport': Icons.directions_car,
  'accommodation': Icons.hotel,
  'entertainment': Icons.movie,
  'daily_necessities': Icons.shopping_bag,
};

class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.customCategories = const [],
    this.onAddCategory,
    this.onDeleteCategory,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final List<GroupCategoryEntity> customCategories;
  final VoidCallback? onAddCategory;
  final ValueChanged<String>? onDeleteCategory;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Built-in categories
        ...builtInCategoryLabels.entries.map((entry) {
          final isSelected = entry.key == selected;
          return ChoiceChip(
            avatar: Icon(
              _builtInIcons[entry.key] ?? Icons.label,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(entry.value),
            selected: isSelected,
            onSelected: (_) => onSelected(entry.key),
          );
        }),
        // Custom categories
        ...customCategories.map((cat) {
          final isSelected = cat.name == selected;
          return GestureDetector(
            onLongPress: onDeleteCategory != null
                ? () => onDeleteCategory!(cat.id)
                : null,
            child: ChoiceChip(
              avatar: Icon(
                resolveIcon(cat.iconName),
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              label: Text(cat.name),
              selected: isSelected,
              onSelected: (_) => onSelected(cat.name),
            ),
          );
        }),
        // Add button
        if (onAddCategory != null)
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('新增'),
            onPressed: onAddCategory,
          ),
      ],
    );
  }
}

/// Returns the display label for a category key.
/// Checks built-in labels first, then falls back to the key itself
/// (which is the custom category name stored as-is).
String categoryLabel(String categoryKey,
    [List<GroupCategoryEntity> customCategories = const []]) {
  if (builtInCategoryLabels.containsKey(categoryKey)) {
    return builtInCategoryLabels[categoryKey]!;
  }
  return categoryKey;
}

/// Returns the icon for a category key.
IconData categoryIcon(String categoryKey,
    [List<GroupCategoryEntity> customCategories = const []]) {
  if (_builtInIcons.containsKey(categoryKey)) {
    return _builtInIcons[categoryKey]!;
  }
  for (final cat in customCategories) {
    if (cat.name == categoryKey) {
      return resolveIcon(cat.iconName);
    }
  }
  return Icons.label;
}
