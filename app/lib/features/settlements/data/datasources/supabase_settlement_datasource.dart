import 'package:app/features/settlements/domain/entities/settlement_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSettlementDataSource {
  const SupabaseSettlementDataSource(this._client);
  final SupabaseClient _client;

  Future<List<BalanceEntity>> getBalances(String groupId) async {
    final response = await _client.rpc(
      'get_user_balances',
      params: {'p_group_id': groupId},
    );

    return (response as List)
        .map((e) => _mapBalance(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OverallBalanceEntity>> getOverallBalances(String userId) async {
    final response = await _client.rpc(
      'get_overall_balances',
      params: {'p_user_id': userId},
    );

    return (response as List)
        .map((e) => _mapOverallBalance(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SettlementEntity>> getSettlements(String groupId) async {
    final response = await _client
        .from('settlements')
        .select()
        .eq('group_id', groupId)
        .order('settled_at', ascending: false);

    return (response as List)
        .map((e) => _mapSettlement(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> markSettled({
    required String groupId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String currency,
  }) async {
    final response = await _client
        .from('settlements')
        .insert({
          'group_id': groupId,
          'from_user': fromUser,
          'to_user': toUser,
          'amount': amount,
          'currency': currency,
          'settled_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  BalanceEntity _mapBalance(Map<String, dynamic> data) {
    return BalanceEntity(
      userId: data['user_id'] as String,
      displayName: data['display_name'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      totalPaid: (data['total_paid'] as num).toDouble(),
      totalOwed: (data['total_owed'] as num).toDouble(),
      netBalance: (data['net_balance'] as num).toDouble(),
    );
  }

  OverallBalanceEntity _mapOverallBalance(Map<String, dynamic> data) {
    return OverallBalanceEntity(
      groupId: data['group_id'] as String,
      groupName: data['group_name'] as String? ?? '',
      netBalance: (data['net_balance'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'TWD',
    );
  }

  SettlementEntity _mapSettlement(Map<String, dynamic> data) {
    return SettlementEntity(
      id: data['id'] as String,
      groupId: data['group_id'] as String,
      fromUser: data['from_user'] as String,
      toUser: data['to_user'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String? ?? 'TWD',
      settledAt: DateTime.parse(data['settled_at'] as String),
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}
