import 'dart:io';

import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/expenses/domain/entities/expense_entity.dart';
import 'package:app/features/expenses/domain/entities/expense_item_entity.dart';
import 'package:app/features/expenses/domain/entities/group_category_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseExpenseDataSource {
  const SupabaseExpenseDataSource(this._client);
  final SupabaseClient _client;

  Future<List<ExpenseEntity>> getExpenses(String groupId) async {
    final response = await _client
        .from('expenses')
        .select('*, expense_splits(*), expense_items(*)')
        .eq('group_id', groupId)
        .order('expense_date', ascending: false);

    return (response as List)
        .map((e) => _mapExpense(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseEntity> getExpenseDetail(String expenseId) async {
    final response = await _client
        .from('expenses')
        .select('*, expense_splits(*), expense_items(*)')
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
    required List<Map<String, dynamic>> items,
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
        'p_items': items,
      },
    );
    return response as String;
  }

  Future<void> updateExpense({
    required String expenseId,
    required String paidBy,
    required double amount,
    required String category,
    required String description,
    String? note,
    required DateTime expenseDate,
    List<Map<String, dynamic>>? splits,
    List<Map<String, dynamic>>? items,
  }) async {
    await _client.rpc(
      'update_expense',
      params: {
        'p_expense_id': expenseId,
        'p_paid_by': paidBy,
        'p_amount': amount,
        'p_category': category,
        'p_description': description,
        'p_note': note,
        'p_expense_date': expenseDate.toIso8601String().split('T').first,
        'p_splits': splits ?? [],
        'p_items': items ?? [],
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
        .insert({'group_id': groupId, 'name': name, 'icon_name': iconName})
        .select()
        .single();

    return _mapGroupCategory(response);
  }

  Future<void> deleteGroupCategory(String categoryId) async {
    await _client.from('group_categories').delete().eq('id', categoryId);
  }

  // --- Attachment helpers ---

  /// Upload a receipt image to Supabase Storage and return its public URL.
  Future<String> uploadAttachment({
    required String expenseId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final ext = filePath.split('.').last.toLowerCase();
    final storagePath =
        '$expenseId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await _client.storage
        .from('receipts')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );

    final publicUrl = _client.storage
        .from('receipts')
        .getPublicUrl(storagePath);
    return publicUrl;
  }

  /// Remove an attachment from storage by its public URL.
  Future<void> removeAttachment(String publicUrl) async {
    // Extract the storage path from the public URL.
    final marker = '/object/public/receipts/';
    final idx = publicUrl.indexOf(marker);
    if (idx < 0) return;
    final path = publicUrl.substring(idx + marker.length);
    await _client.storage.from('receipts').remove([path]);
  }

  /// Update the attachment_urls column on an expense row.
  Future<void> updateAttachmentUrls({
    required String expenseId,
    required List<String> urls,
  }) async {
    await _client
        .from('expenses')
        .update({'attachment_urls': urls})
        .eq('id', expenseId);
  }

  // --- Mapping helpers ---

  ExpenseEntity _mapExpense(Map<String, dynamic> data) {
    final splitsData = data['expense_splits'] as List? ?? [];
    final itemsData = (data['expense_items'] as List? ?? [])
      ..sort((a, b) {
        final left =
            DateTime.tryParse(
              (a as Map<String, dynamic>)['created_at'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final right =
            DateTime.tryParse(
              (b as Map<String, dynamic>)['created_at'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
    final attachments = data['attachment_urls'] as List?;
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
      items: itemsData.map(_mapItem).toList(),
      attachmentUrls: attachments?.map((e) => e as String).toList() ?? const [],
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

  ExpenseItemEntity _mapItem(dynamic data) {
    final map = data as Map<String, dynamic>;
    return ExpenseItemEntity(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      sharedByUserIds: (map['shared_by_user_ids'] as List? ?? const [])
          .map((e) => e as String)
          .toList(),
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
