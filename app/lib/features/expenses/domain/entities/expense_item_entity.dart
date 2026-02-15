class ExpenseItemEntity {
  const ExpenseItemEntity({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.amount,
    required this.sharedByUserIds,
  });

  final String id;
  final String expenseId;
  final String name;
  final double amount;
  final List<String> sharedByUserIds;
}
