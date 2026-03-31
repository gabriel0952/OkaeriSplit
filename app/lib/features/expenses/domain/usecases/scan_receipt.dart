import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';

class ScanReceipt {
  const ScanReceipt(this._repository);
  final ReceiptScanRepository _repository;

  Future<AppResult<ScanResultEntity>> call({
    required File imageFile,
    OcrLanguage language = OcrLanguage.auto,
    ReceiptScanMethod method = ReceiptScanMethod.local,
    String? userId,
  }) {
    return _repository.scanReceipt(
      imageFile,
      language: language,
      method: method,
      userId: userId,
    );
  }
}
