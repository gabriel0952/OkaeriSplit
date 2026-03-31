import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class GeminiScanSettingsDatasource {
  GeminiScanSettingsDatasource(this._secureStorage);

  static const _boxName = 'settings';
  static const _preferredMethodPrefix = 'receipt_scan_preferred_method:';
  static const _usageNoticePrefix = 'gemini_usage_notice_ack:';
  static const _apiKeyPrefix = 'gemini_api_key:';

  final FlutterSecureStorage _secureStorage;

  Box get _settingsBox => Hive.box(_boxName);

  Future<String?> readApiKey(String userId) {
    return _secureStorage.read(key: '$_apiKeyPrefix$userId');
  }

  Future<void> saveApiKey(String userId, String apiKey) {
    return _secureStorage.write(key: '$_apiKeyPrefix$userId', value: apiKey);
  }

  Future<void> deleteApiKey(String userId) {
    return _secureStorage.delete(key: '$_apiKeyPrefix$userId');
  }

  ReceiptScanMethod readPreferredMethod(String userId) {
    final value =
        _settingsBox.get(
              '$_preferredMethodPrefix$userId',
              defaultValue: ReceiptScanMethod.local.name,
            )
            as String;

    return ReceiptScanMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => ReceiptScanMethod.local,
    );
  }

  Future<void> savePreferredMethod(
    String userId,
    ReceiptScanMethod method,
  ) async {
    await _settingsBox.put('$_preferredMethodPrefix$userId', method.name);
  }

  bool readUsageNoticeAcknowledged(String userId) {
    return _settingsBox.get('$_usageNoticePrefix$userId', defaultValue: false)
        as bool;
  }

  Future<void> saveUsageNoticeAcknowledged(String userId) async {
    await _settingsBox.put('$_usageNoticePrefix$userId', true);
  }
}
