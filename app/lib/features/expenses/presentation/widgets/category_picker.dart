import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:app/features/expenses/presentation/widgets/icon_picker_dialog.dart';
import 'package:flutter/material.dart';

/// Built-in category definitions (key → icon).
const _builtInIcons = <String, IconData>{
  'food': Icons.restaurant_rounded,
  'transport': Icons.directions_car_rounded,
  'accommodation': Icons.hotel_rounded,
  'entertainment': Icons.movie_rounded,
  'daily_necessities': Icons.shopping_bag_rounded,
};

// Tasks 4.2–4.4: Horizontal tile-based CategoryPicker
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
    final builtIns = builtInCategoryLabels.entries.toList();
    final customs = customCategories;
    final totalCount = builtIns.length + customs.length;

    return SizedBox(
      height: 76,
      child: Row(
        children: [
          // Horizontally scrollable category tiles
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: totalCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index < builtIns.length) {
                  final entry = builtIns[index];
                  final isSelected = entry.key == selected;
                  return _CategoryTile(
                    icon: _builtInIcons[entry.key] ?? Icons.label_rounded,
                    label: entry.value,
                    isSelected: isSelected,
                    onTap: () => onSelected(entry.key),
                  );
                } else {
                  final cat = customs[index - builtIns.length];
                  final isSelected = cat.name == selected;
                  return GestureDetector(
                    onLongPress: onDeleteCategory != null
                        ? () => onDeleteCategory!(cat.id)
                        : null,
                    child: _CategoryTile(
                      icon: resolveIcon(cat.iconName),
                      label: cat.name,
                      isSelected: isSelected,
                      onTap: () => onSelected(cat.name),
                    ),
                  );
                }
              },
            ),
          ),
          // Task 4.4: Fixed add-custom button, does not scroll away
          if (onAddCategory != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: _AddCategoryButton(onTap: onAddCategory!),
            ),
        ],
      ),
    );
  }
}

// Task 4.3: 60×64px rounded square tile, icon on top + label below
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        height: 72,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? null
              : Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.white
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  const _AddCategoryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Returns the display label for a category key.
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
  return Icons.label_rounded;
}
