import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class PendingExpenseDto {
  const PendingExpenseDto({
    required this.localId,
    required this.groupId,
    required this.paidBy,
    required this.amount,
    required this.currency,
    required this.category,
    required this.description,
    this.note,
    required this.expenseDate,
    required this.splits,
    required this.items,
    required this.pendingAt,
  });

  final String localId;
  final String groupId;
  final String paidBy;
  final double amount;
  final String currency;
  final String category;
  final String description;
  final String? note;
  final DateTime expenseDate;
  final List<Map<String, dynamic>> splits;
  final List<Map<String, dynamic>> items;
  final DateTime pendingAt;

  Map<String, dynamic> toJson() => {
    'local_id': localId,
    'group_id': groupId,
    'paid_by': paidBy,
    'amount': amount,
    'currency': currency,
    'category': category,
    'description': description,
    'note': note,
    'expense_date': expenseDate.toIso8601String(),
    'splits': splits,
    'items': items,
    'pending_at': pendingAt.toIso8601String(),
  };

  factory PendingExpenseDto.fromJson(Map<String, dynamic> j) =>
      PendingExpenseDto(
        localId: j['local_id'] as String,
        groupId: j['group_id'] as String,
        paidBy: j['paid_by'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String,
        category: j['category'] as String,
        description: j['description'] as String,
        note: j['note'] as String?,
        expenseDate: DateTime.parse(j['expense_date'] as String),
        splits: (j['splits'] as List).cast<Map<String, dynamic>>(),
        items: (j['items'] as List? ?? const []).cast<Map<String, dynamic>>(),
        pendingAt: DateTime.parse(j['pending_at'] as String),
      );
}

class PendingExpenseRepository {
  Box get _box => Hive.box('pending_expenses');

  Future<void> add(PendingExpenseDto dto) async {
    await _box.put(dto.localId, jsonEncode(dto.toJson()));
  }

  List<PendingExpenseDto> getAll() {
    return _box.values
        .map(
          (v) => PendingExpenseDto.fromJson(
            jsonDecode(v as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> remove(String localId) async {
    await _box.delete(localId);
  }

  int count() => _box.length;
}
