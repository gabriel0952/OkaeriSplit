import 'package:flutter/material.dart';

/// A map from icon name (stored in DB) to the Material [IconData].
const categoryIconMap = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'hotel': Icons.hotel,
  'movie': Icons.movie,
  'shopping_bag': Icons.shopping_bag,
  'local_cafe': Icons.local_cafe,
  'flight': Icons.flight,
  'train': Icons.train,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'pets': Icons.pets,
  'fitness_center': Icons.fitness_center,
  'sports_esports': Icons.sports_esports,
  'music_note': Icons.music_note,
  'brush': Icons.brush,
  'build': Icons.build,
  'card_giftcard': Icons.card_giftcard,
  'child_care': Icons.child_care,
  'phone_android': Icons.phone_android,
  'home': Icons.home,
};

/// Resolves an icon name to [IconData], falling back to [Icons.label].
IconData resolveIcon(String iconName) {
  return categoryIconMap[iconName] ?? Icons.label;
}

/// Dialog that lets the user pick a Material icon for a custom category.
class IconPickerDialog extends StatelessWidget {
  const IconPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = categoryIconMap.entries.toList();
    return AlertDialog(
      title: const Text('選擇圖示'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).pop(entry.key),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: Icon(entry.value, size: 24),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
