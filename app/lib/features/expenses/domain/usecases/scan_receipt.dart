import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';

class ScanReceipt {
  const ScanReceipt(this._repository);
  final ReceiptScanRepository _repository;

  Future<AppResult<ScanResultEntity>> call({required File imageFile}) {
    return _repository.scanReceipt(imageFile);
  }
}
