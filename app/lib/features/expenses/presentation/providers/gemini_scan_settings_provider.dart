import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/data/datasources/gemini_scan_settings_datasource.dart';
import 'package:app/features/expenses/data/repositories/gemini_scan_settings_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/gemini_scan_settings_entity.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/repositories/gemini_scan_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final geminiScanSettingsDatasourceProvider =
    Provider<GeminiScanSettingsDatasource>((ref) {
      return GeminiScanSettingsDatasource(ref.watch(secureStorageProvider));
    });

final geminiScanSettingsRepositoryProvider =
    Provider<GeminiScanSettingsRepository>((ref) {
      return GeminiScanSettingsRepositoryImpl(
        ref.watch(geminiScanSettingsDatasourceProvider),
      );
    });

final currentGeminiScanSettingsProvider =
    FutureProvider<GeminiScanSettingsEntity?>((ref) async {
      final user = ref.watch(authStateProvider).valueOrNull;
      if (user == null) return null;
      return ref
          .watch(geminiScanSettingsRepositoryProvider)
          .getSettings(userId: user.id);
    });

class GeminiScanSettingsController {
  GeminiScanSettingsController(this._ref);

  final Ref _ref;

  GeminiScanSettingsRepository get _repository =>
      _ref.read(geminiScanSettingsRepositoryProvider);

  Future<GeminiScanSettingsEntity> loadCurrentUserSettings() async {
    final user = _requireCurrentUserId();
    return _repository.getSettings(userId: user);
  }

  Future<void> saveApiKey(String apiKey) async {
    final user = _requireCurrentUserId();
    await _repository.saveApiKey(userId: user, apiKey: apiKey);
    _invalidate();
  }

  Future<void> deleteApiKey() async {
    final user = _requireCurrentUserId();
    await _repository.deleteApiKey(userId: user);
    _invalidate();
  }

  Future<String?> getApiKey() async {
    final user = _requireCurrentUserId();
    return _repository.getApiKey(userId: user);
  }

  Future<void> setPreferredMethod(ReceiptScanMethod method) async {
    final user = _requireCurrentUserId();
    await _repository.setPreferredMethod(userId: user, method: method);
    _invalidate();
  }

  Future<void> markUsageNoticeAcknowledged() async {
    final user = _requireCurrentUserId();
    await _repository.markUsageNoticeAcknowledged(userId: user);
    _invalidate();
  }

  String _requireCurrentUserId() {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      throw StateError('請先登入帳號後再使用 Gemini 掃描');
    }
    return user.id;
  }

  void _invalidate() {
    _ref.invalidate(currentGeminiScanSettingsProvider);
  }
}

final geminiScanSettingsControllerProvider = Provider((ref) {
  return GeminiScanSettingsController(ref);
});
