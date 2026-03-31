import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/gemini_receipt_scan_datasource.dart';
import 'package:app/features/expenses/data/datasources/gemini_scan_settings_datasource.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/data/repositories/receipt_scan_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReceiptScanDatasource extends Mock implements ReceiptScanDatasource {}

class MockGeminiReceiptScanDatasource extends Mock
    implements GeminiReceiptScanDatasource {}

class MockGeminiScanSettingsDatasource extends Mock
    implements GeminiScanSettingsDatasource {}

void main() {
  late MockReceiptScanDatasource localDatasource;
  late MockGeminiReceiptScanDatasource geminiDatasource;
  late MockGeminiScanSettingsDatasource settingsDatasource;
  late ReceiptScanRepositoryImpl repository;

  final imageFile = File('receipt.jpg');
  const localResult = ScanResultEntity(
    items: [ScanResultItemEntity(name: 'Lunch', amount: 120)],
    total: 120,
  );
  const geminiResult = ScanResultEntity(
    items: [ScanResultItemEntity(name: 'Dinner', amount: 350)],
    total: 350,
    lowConfidence: true,
  );

  setUpAll(() {
    registerFallbackValue(File('fallback.jpg'));
  });

  setUp(() {
    localDatasource = MockReceiptScanDatasource();
    geminiDatasource = MockGeminiReceiptScanDatasource();
    settingsDatasource = MockGeminiScanSettingsDatasource();
    repository = ReceiptScanRepositoryImpl(
      localDatasource,
      geminiDatasource,
      settingsDatasource,
    );
  });

  test('uses local datasource for local scan method', () async {
    when(
      () => localDatasource.scanReceipt(imageFile, language: OcrLanguage.auto),
    ).thenAnswer((_) async => localResult);

    final result = await repository.scanReceipt(
      imageFile,
      method: ReceiptScanMethod.local,
    );

    expect(result.isRight(), isTrue);
    verify(
      () => localDatasource.scanReceipt(imageFile, language: OcrLanguage.auto),
    ).called(1);
    verifyNever(
      () => geminiDatasource.scanReceipt(
        any(),
        apiKey: any(named: 'apiKey'),
        language: OcrLanguage.auto,
      ),
    );
  });

  test('returns friendly failure when Gemini key is missing', () async {
    when(
      () => settingsDatasource.readApiKey('user-1'),
    ).thenAnswer((_) async => null);

    final result = await repository.scanReceipt(
      imageFile,
      method: ReceiptScanMethod.gemini,
      userId: 'user-1',
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure.message, '請先設定 Gemini API key'),
      (_) => fail('expected Left'),
    );
  });

  test('maps Gemini invalid-key exception to user-facing failure', () async {
    when(
      () => settingsDatasource.readApiKey('user-1'),
    ).thenAnswer((_) async => 'AIza-test-key');
    when(
      () => geminiDatasource.scanReceipt(
        imageFile,
        apiKey: 'AIza-test-key',
        language: OcrLanguage.auto,
      ),
    ).thenThrow(
      const GeminiScanException(
        GeminiScanErrorCode.invalidKey,
        'internal upstream auth failure',
      ),
    );

    final result = await repository.scanReceipt(
      imageFile,
      method: ReceiptScanMethod.gemini,
      userId: 'user-1',
    );

    expect(result.isLeft(), isTrue);
    result.fold((failure) {
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Gemini API key 無效，請更新後重試');
    }, (_) => fail('expected Left'));
  });

  test('maps Gemini rate-limited exception to user-facing failure', () async {
    when(
      () => settingsDatasource.readApiKey('user-1'),
    ).thenAnswer((_) async => 'AIza-test-key');
    when(
      () => geminiDatasource.scanReceipt(
        imageFile,
        apiKey: 'AIza-test-key',
        language: OcrLanguage.auto,
      ),
    ).thenThrow(
      const GeminiScanException(
        GeminiScanErrorCode.rateLimited,
        'upstream resource exhausted',
      ),
    );

    final result = await repository.scanReceipt(
      imageFile,
      method: ReceiptScanMethod.gemini,
      userId: 'user-1',
    );

    expect(result.isLeft(), isTrue);
    result.fold((failure) {
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Gemini 請求過於頻繁或暫時受限，請稍後再試');
    }, (_) => fail('expected Left'));
  });

  test('returns Gemini result when key exists and scan succeeds', () async {
    when(
      () => settingsDatasource.readApiKey('user-1'),
    ).thenAnswer((_) async => 'AIza-test-key');
    when(
      () => geminiDatasource.scanReceipt(
        imageFile,
        apiKey: 'AIza-test-key',
        language: OcrLanguage.auto,
      ),
    ).thenAnswer((_) async => geminiResult);

    final result = await repository.scanReceipt(
      imageFile,
      method: ReceiptScanMethod.gemini,
      userId: 'user-1',
    );

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (scanResult) {
      expect(scanResult.total, 350);
      expect(scanResult.lowConfidence, isTrue);
      expect(scanResult.items.single.name, 'Dinner');
    });
  });
}
