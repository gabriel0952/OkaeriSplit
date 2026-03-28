import 'dart:async';
import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';
import 'package:fpdart/fpdart.dart';

class ReceiptScanRepositoryImpl implements ReceiptScanRepository {
  const ReceiptScanRepositoryImpl(this._datasource);
  final ReceiptScanDatasource _datasource;

  @override
  Future<AppResult<ScanResultEntity>> scanReceipt(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    try {
      final result = await _datasource.scanReceipt(
        imageFile,
        language: language,
      );
      return Right(result);
    } on StateError catch (e) {
      return Left(ServerFailure('模型未就緒：${e.message}'));
    } on TimeoutException {
      return const Left(ServerFailure('辨識逾時，請重試'));
    } catch (e) {
      return Left(ServerFailure('辨識失敗：$e'));
    }
  }
}
