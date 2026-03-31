import 'package:app/features/expenses/data/datasources/gemini_scan_settings_datasource.dart';
import 'package:app/features/expenses/data/repositories/gemini_scan_settings_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class InMemoryGeminiScanSettingsDatasource
    extends GeminiScanSettingsDatasource {
  InMemoryGeminiScanSettingsDatasource() : super(MockFlutterSecureStorage());

  final Map<String, String> _apiKeys = {};
  final Map<String, ReceiptScanMethod> _preferredMethods = {};
  final Set<String> _acknowledgedUsers = {};

  @override
  Future<String?> readApiKey(String userId) async => _apiKeys[userId];

  @override
  Future<void> saveApiKey(String userId, String apiKey) async {
    _apiKeys[userId] = apiKey;
  }

  @override
  Future<void> deleteApiKey(String userId) async {
    _apiKeys.remove(userId);
  }

  @override
  ReceiptScanMethod readPreferredMethod(String userId) {
    return _preferredMethods[userId] ?? ReceiptScanMethod.local;
  }

  @override
  Future<void> savePreferredMethod(
    String userId,
    ReceiptScanMethod method,
  ) async {
    _preferredMethods[userId] = method;
  }

  @override
  bool readUsageNoticeAcknowledged(String userId) {
    return _acknowledgedUsers.contains(userId);
  }

  @override
  Future<void> saveUsageNoticeAcknowledged(String userId) async {
    _acknowledgedUsers.add(userId);
  }
}

void main() {
  late InMemoryGeminiScanSettingsDatasource datasource;
  late GeminiScanSettingsRepositoryImpl repository;

  setUp(() {
    datasource = InMemoryGeminiScanSettingsDatasource();
    repository = GeminiScanSettingsRepositoryImpl(datasource);
  });

  test('stores keys per user and masks the displayed value', () async {
    await repository.saveApiKey(userId: 'user-a', apiKey: 'AIza-user-a-1234');
    await repository.saveApiKey(userId: 'user-b', apiKey: 'AIza-user-b-9876');
    await repository.setPreferredMethod(
      userId: 'user-b',
      method: ReceiptScanMethod.gemini,
    );
    await repository.markUsageNoticeAcknowledged(userId: 'user-b');

    final userA = await repository.getSettings(userId: 'user-a');
    final userB = await repository.getSettings(userId: 'user-b');

    expect(userA.hasApiKey, isTrue);
    expect(userA.maskedApiKey, '••••1234');
    expect(userA.preferredMethod, ReceiptScanMethod.local);
    expect(userA.hasAcknowledgedUsageNotice, isFalse);

    expect(userB.hasApiKey, isTrue);
    expect(userB.maskedApiKey, '••••9876');
    expect(userB.preferredMethod, ReceiptScanMethod.gemini);
    expect(userB.hasAcknowledgedUsageNotice, isTrue);
  });

  test('deleting one user key does not affect another user', () async {
    await repository.saveApiKey(userId: 'user-a', apiKey: 'AIza-user-a-1234');
    await repository.saveApiKey(userId: 'user-b', apiKey: 'AIza-user-b-9876');

    await repository.deleteApiKey(userId: 'user-a');

    expect(await repository.getApiKey(userId: 'user-a'), isNull);
    expect(await repository.getApiKey(userId: 'user-b'), 'AIza-user-b-9876');
  });

  test('rejects blank API key input', () async {
    expect(
      () => repository.saveApiKey(userId: 'user-a', apiKey: '   '),
      throwsA(isA<StateError>()),
    );
  });
}
