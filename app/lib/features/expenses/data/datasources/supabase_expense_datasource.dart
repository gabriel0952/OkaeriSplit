import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseExpenseDataSource {
  const SupabaseExpenseDataSource(this._client);
  final SupabaseClient _client;

  Future<List<ExpenseEntity>> getExpenses(String groupId) async {
    final response = await _client
        .from('expenses')
        .select('*, expense_splits(*)')
        .eq('group_id', groupId)
        .order('expense_date', ascending: false);

    return (response as List)
        .map((e) => _mapExpense(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseEntity> getExpenseDetail(String expenseId) async {
    final response = await _client
        .from('expenses')
        .select('*, expense_splits(*)')
        .eq('id', expenseId)
        .single();

    return _mapExpense(response);
  }

  Future<String> createExpense({
    required String groupId,
    required String paidBy,
    required double amount,
    required String currency,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    required List<Map<String, dynamic>> splits,
  }) async {
    final response = await _client.rpc(
      'create_expense',
      params: {
        'p_group_id': groupId,
        'p_paid_by': paidBy,
        'p_amount': amount,
        'p_currency': currency,
        'p_category': category,
        'p_description': description,
        'p_note': note,
        'p_expense_date': expenseDate.toIso8601String().split('T').first,
        'p_splits': splits,
      },
    );
    return response as String;
  }

  Future<void> updateExpense({
    required String expenseId,
    required double amount,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
  }) async {
    await _client
        .from('expenses')
        .update({
          'amount': amount,
          'category': category,
          'description': description,
          'note': note,
          'expense_date': expenseDate.toIso8601String().split('T').first,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', expenseId);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }

  ExpenseEntity _mapExpense(Map<String, dynamic> data) {
    final splitsData = data['expense_splits'] as List? ?? [];
    return ExpenseEntity(
      id: data['id'] as String,
      groupId: data['group_id'] as String,
      paidBy: data['paid_by'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'TWD',
      category: _mapCategory(data['category'] as String?),
      description: data['description'] as String? ?? '',
      note: data['note'] as String?,
      expenseDate: DateTime.parse(data['expense_date'] as String),
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      splits: splitsData.map(_mapSplit).toList(),
    );
  }

  ExpenseSplitEntity _mapSplit(dynamic data) {
    final map = data as Map<String, dynamic>;
    return ExpenseSplitEntity(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      splitType: SplitType.values.firstWhere(
        (e) => toSnakeCase(e.name) == map['split_type'],
        orElse: () => SplitType.equal,
      ),
    );
  }

  ExpenseCategory _mapCategory(String? value) {
    if (value == null) return ExpenseCategory.other;
    return ExpenseCategory.values.firstWhere(
      (e) => toSnakeCase(e.name) == value,
      orElse: () => ExpenseCategory.other,
    );
  }

  static String toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }
}
