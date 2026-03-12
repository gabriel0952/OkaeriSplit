import 'dart:convert';

import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveExpenseDataSource {
  Box get _box => Hive.box('expenses_cache');

  Future<void> saveExpenses(String groupId, List<ExpenseEntity> expenses) async {
    final json = jsonEncode(expenses.map(_expenseToJson).toList());
    await _box.put(groupId, json);
  }

  List<ExpenseEntity> getExpenses(String groupId) {
    final raw = _box.get(groupId) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _expenseFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Serialization helpers ---

  Map<String, dynamic> _expenseToJson(ExpenseEntity e) => {
        'id': e.id,
        'group_id': e.groupId,
        'paid_by': e.paidBy,
        'amount': e.amount,
        'currency': e.currency,
        'category': e.category,
        'description': e.description,
        'note': e.note,
        'expense_date': e.expenseDate.toIso8601String(),
        'created_at': e.createdAt.toIso8601String(),
        'updated_at': e.updatedAt.toIso8601String(),
        'splits': e.splits.map(_splitToJson).toList(),
        'attachment_urls': e.attachmentUrls,
      };

  ExpenseEntity _expenseFromJson(Map<String, dynamic> j) => ExpenseEntity(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        paidBy: j['paid_by'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'TWD',
        category: j['category'] as String? ?? 'food',
        description: j['description'] as String? ?? '',
        note: j['note'] as String?,
        expenseDate: DateTime.parse(j['expense_date'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        splits: (j['splits'] as List? ?? [])
            .map((s) => _splitFromJson(s as Map<String, dynamic>))
            .toList(),
        attachmentUrls:
            (j['attachment_urls'] as List? ?? []).cast<String>(),
      );

  Map<String, dynamic> _splitToJson(ExpenseSplitEntity s) => {
        'id': s.id,
        'expense_id': s.expenseId,
        'user_id': s.userId,
        'amount': s.amount,
        'split_type': s.splitType.name,
      };

  ExpenseSplitEntity _splitFromJson(Map<String, dynamic> j) =>
      ExpenseSplitEntity(
        id: j['id'] as String,
        expenseId: j['expense_id'] as String,
        userId: j['user_id'] as String,
        amount: (j['amount'] as num).toDouble(),
        splitType: SplitType.values.firstWhere(
          (e) => e.name == j['split_type'],
          orElse: () => SplitType.equal,
        ),
      );
}
