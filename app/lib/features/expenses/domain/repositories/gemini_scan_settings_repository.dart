import 'package:app/features/expenses/domain/entities/gemini_scan_settings_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';

abstract class GeminiScanSettingsRepository {
  Future<GeminiScanSettingsEntity> getSettings({required String userId});

  Future<String?> getApiKey({required String userId});

  Future<void> saveApiKey({required String userId, required String apiKey});

  Future<void> deleteApiKey({required String userId});

  Future<void> setPreferredMethod({
    required String userId,
    required ReceiptScanMethod method,
  });

  Future<void> markUsageNoticeAcknowledged({required String userId});
}
