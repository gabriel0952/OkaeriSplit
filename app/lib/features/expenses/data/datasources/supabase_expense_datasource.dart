import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
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
    List<Map<String, dynamic>>? splits,
  }) async {
    await _client.rpc(
      'update_expense',
      params: {
        'p_expense_id': expenseId,
        'p_amount': amount,
        'p_category': category,
        'p_description': description,
        'p_note': note,
        'p_expense_date': expenseDate.toIso8601String().split('T').first,
        'p_splits': splits ?? [],
      },
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }

  // --- Group Categories CRUD ---

  Future<List<GroupCategoryEntity>> getGroupCategories(String groupId) async {
    final response = await _client
        .from('group_categories')
        .select()
        .eq('group_id', groupId)
        .order('created_at');

    return (response as List)
        .map((e) => _mapGroupCategory(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupCategoryEntity> createGroupCategory({
    required String groupId,
    required String name,
    required String iconName,
  }) async {
    final response = await _client
        .from('group_categories')
        .insert({
          'group_id': groupId,
          'name': name,
          'icon_name': iconName,
        })
        .select()
        .single();

    return _mapGroupCategory(response);
  }

  Future<void> deleteGroupCategory(String categoryId) async {
    await _client.from('group_categories').delete().eq('id', categoryId);
  }

  // --- Mapping helpers ---

  ExpenseEntity _mapExpense(Map<String, dynamic> data) {
    final splitsData = data['expense_splits'] as List? ?? [];
    return ExpenseEntity(
      id: data['id'] as String,
      groupId: data['group_id'] as String,
      paidBy: data['paid_by'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'TWD',
      category: data['category'] as String? ?? 'food',
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

  GroupCategoryEntity _mapGroupCategory(Map<String, dynamic> data) {
    return GroupCategoryEntity(
      id: data['id'] as String,
      groupId: data['group_id'] as String,
      name: data['name'] as String,
      iconName: data['icon_name'] as String,
    );
  }

  static String toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }
}
