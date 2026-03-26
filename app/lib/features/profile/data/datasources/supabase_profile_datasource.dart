import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:app/features/profile/domain/entities/payment_info_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileDataSource {
  const SupabaseProfileDataSource(this._client);
  final SupabaseClient _client;

  Future<UserEntity> getProfile(String userId) async {
    final response =
        await _client.from('profiles').select().eq('id', userId).single();
    return _mapProfile(response);
  }

  Future<UserEntity> updateProfile(
    String userId, {
    String? displayName,
    String? defaultCurrency,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (defaultCurrency != null) updates['default_currency'] = defaultCurrency;

    final response = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return _mapProfile(response);
  }

  Future<PaymentInfoEntity?> getPaymentInfo(String userId) async {
    final response = await _client
        .from('profiles')
        .select('payment_info')
        .eq('id', userId)
        .single();
    final raw = response['payment_info'] as Map<String, dynamic>?;
    return raw == null ? null : _mapPaymentInfo(raw);
  }

  Future<void> updatePaymentInfo(
    String userId,
    PaymentInfoEntity? paymentInfo,
  ) async {
    await _client
        .from('profiles')
        .update({'payment_info': paymentInfo == null ? null : _paymentInfoToJson(paymentInfo)})
        .eq('id', userId);
  }

  UserEntity _mapProfile(Map<String, dynamic> data) {
    final raw = data['payment_info'] as Map<String, dynamic>?;
    return UserEntity(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      defaultCurrency: data['default_currency'] as String? ?? 'TWD',
      paymentInfo: raw == null ? null : _mapPaymentInfo(raw),
    );
  }

  PaymentInfoEntity _mapPaymentInfo(Map<String, dynamic> data) {
    return PaymentInfoEntity(
      bankName: data['bank_name'] as String? ?? '',
      bankCode: data['bank_code'] as String? ?? '',
      accountNumber: data['account_number'] as String? ?? '',
    );
  }

  Map<String, dynamic> _paymentInfoToJson(PaymentInfoEntity info) {
    return {
      'bank_name': info.bankName,
      'bank_code': info.bankCode,
      'account_number': info.accountNumber,
    };
  }
}
