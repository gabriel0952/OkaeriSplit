class CategoryStatEntity {
  const CategoryStatEntity({
    required this.category,
    required this.label,
    required this.totalAmount,
    required this.percentage,
  });

  final String category;
  final String label;
  final double totalAmount;
  final double percentage;
}

class MonthlyStatEntity {
  const MonthlyStatEntity({
    required this.yearMonth,
    required this.totalAmount,
  });

  final String yearMonth;
  final double totalAmount;
}
