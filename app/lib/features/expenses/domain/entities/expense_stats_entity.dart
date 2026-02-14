import 'package:app/core/constants/app_constants.dart';

class CategoryStatEntity {
  const CategoryStatEntity({
    required this.category,
    required this.totalAmount,
    required this.percentage,
  });

  final ExpenseCategory category;
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
