import 'dart:async';
import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/gemini_receipt_scan_datasource.dart';
import 'package:app/features/expenses/data/datasources/gemini_scan_settings_datasource.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/services.dart';

class ReceiptScanRepositoryImpl implements ReceiptScanRepository {
  const ReceiptScanRepositoryImpl(
    this._localDatasource,
    this._geminiDatasource,
    this._settingsDatasource,
  );

  final ReceiptScanDatasource _localDatasource;
  final GeminiReceiptScanDatasource _geminiDatasource;
  final GeminiScanSettingsDatasource _settingsDatasource;

  @override
  Future<AppResult<ScanResultEntity>> scanReceipt(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
    ReceiptScanMethod method = ReceiptScanMethod.local,
    String? userId,
  }) async {
    try {
      final result = switch (method) {
        ReceiptScanMethod.local => await _localDatasource.scanReceipt(
          imageFile,
          language: language,
        ),
        ReceiptScanMethod.gemini => await _scanWithGemini(
          imageFile,
          language: language,
          userId: userId,
        ),
      };
      return Right(result);
    } on MissingPluginException {
      return const Left(UnsupportedFeatureFailure('此裝置目前不支援收據掃描'));
    } on GeminiScanException catch (e) {
      return Left(ServerFailure(_mapGeminiError(e)));
    } on UnsupportedError catch (e) {
      return Left(UnsupportedFeatureFailure(e.message ?? '此裝置不支援收據掃描'));
    } on StateError catch (e) {
      return Left(ServerFailure('模型未就緒：${e.message}'));
    } on TimeoutException {
      return const Left(ServerFailure('辨識逾時，請重試'));
    } catch (e) {
      return Left(ServerFailure('辨識失敗：$e'));
    }
  }

  Future<ScanResultEntity> _scanWithGemini(
    File imageFile, {
    required OcrLanguage language,
    required String? userId,
  }) async {
    if (userId == null) {
      throw const GeminiScanException(
        GeminiScanErrorCode.notAuthenticated,
        '請先登入帳號後再使用 Gemini 掃描',
      );
    }

    final apiKey = await _settingsDatasource.readApiKey(userId);
    final trimmedApiKey = apiKey?.trim();
    if (trimmedApiKey == null || trimmedApiKey.isEmpty) {
      throw const GeminiScanException(
        GeminiScanErrorCode.missingKey,
        '請先設定 Gemini API key',
      );
    }

    return _geminiDatasource.scanReceipt(
      imageFile,
      apiKey: trimmedApiKey,
      language: language,
    );
  }

  String _mapGeminiError(GeminiScanException exception) {
    return switch (exception.code) {
      GeminiScanErrorCode.notAuthenticated => exception.message,
      GeminiScanErrorCode.missingKey => exception.message,
      GeminiScanErrorCode.invalidKey => 'Gemini API key 無效，請更新後重試',
      GeminiScanErrorCode.quotaExceeded => 'Gemini API key 配額不足或計費設定異常，請稍後再試',
      GeminiScanErrorCode.timeout => 'Gemini 掃描逾時，請重試',
      GeminiScanErrorCode.payloadTooLarge => exception.message,
      GeminiScanErrorCode.rateLimited => 'Gemini 請求過於頻繁或暫時受限，請稍後再試',
      GeminiScanErrorCode.schemaInvalid => 'Gemini 掃描結果格式異常，請重試或改用本地 OCR',
      GeminiScanErrorCode.upstreamFailure => exception.message,
    };
  }
}
