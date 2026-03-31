import 'package:app/features/expenses/data/datasources/gemini_scan_settings_datasource.dart';
import 'package:app/features/expenses/domain/entities/gemini_scan_settings_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/repositories/gemini_scan_settings_repository.dart';

class GeminiScanSettingsRepositoryImpl implements GeminiScanSettingsRepository {
  const GeminiScanSettingsRepositoryImpl(this._datasource);

  final GeminiScanSettingsDatasource _datasource;

  @override
  Future<GeminiScanSettingsEntity> getSettings({required String userId}) async {
    final apiKey = await _datasource.readApiKey(userId);
    final trimmed = apiKey?.trim();

    return GeminiScanSettingsEntity(
      hasApiKey: trimmed != null && trimmed.isNotEmpty,
      maskedApiKey: _maskApiKey(trimmed),
      preferredMethod: _datasource.readPreferredMethod(userId),
      hasAcknowledgedUsageNotice: _datasource.readUsageNoticeAcknowledged(
        userId,
      ),
    );
  }

  @override
  Future<String?> getApiKey({required String userId}) async {
    final apiKey = await _datasource.readApiKey(userId);
    final trimmed = apiKey?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Future<void> saveApiKey({
    required String userId,
    required String apiKey,
  }) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      throw StateError('請輸入 Gemini API key');
    }
    await _datasource.saveApiKey(userId, normalized);
  }

  @override
  Future<void> deleteApiKey({required String userId}) {
    return _datasource.deleteApiKey(userId);
  }

  @override
  Future<void> setPreferredMethod({
    required String userId,
    required ReceiptScanMethod method,
  }) {
    return _datasource.savePreferredMethod(userId, method);
  }

  @override
  Future<void> markUsageNoticeAcknowledged({required String userId}) {
    return _datasource.saveUsageNoticeAcknowledged(userId);
  }

  String? _maskApiKey(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return null;
    if (apiKey.length <= 4) return '••••';
    return '••••${apiKey.substring(apiKey.length - 4)}';
  }
}
