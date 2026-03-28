import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_item_entity.dart';

class ExpenseEntity {
  const ExpenseEntity({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.amount,
    required this.currency,
    required this.category,
    required this.description,
    this.note,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.splits = const [],
    this.items = const [],
    this.attachmentUrls = const [],
    this.isPending = false,
  });

  final String id;
  final String groupId;
  final String paidBy;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final String? note;
  final DateTime expenseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExpenseSplitEntity> splits;
  final List<ExpenseItemEntity> items;
  final List<String> attachmentUrls;

  /// True when this expense is stored locally and not yet synced to the server.
  final bool isPending;
}

class ExpenseSplitEntity {
  const ExpenseSplitEntity({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amount,
    required this.splitType,
  });

  final String id;
  final String expenseId;
  final String userId;
  final double amount;
  final SplitType splitType;
}
