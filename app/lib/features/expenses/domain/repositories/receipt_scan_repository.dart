import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';

abstract class ReceiptScanRepository {
  Future<AppResult<ScanResultEntity>> scanReceipt(
    File imageFile, {
    OcrLanguage language,
    ReceiptScanMethod method,
    String? userId,
  });
}
