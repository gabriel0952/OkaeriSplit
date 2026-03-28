import 'dart:io';

import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/data/repositories/receipt_scan_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';
import 'package:app/features/expenses/domain/usecases/scan_receipt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final receiptScanDatasourceProvider = Provider<ReceiptScanDatasource>((ref) {
  return ReceiptScanDatasource();
});

final receiptScanRepositoryProvider = Provider<ReceiptScanRepository>((ref) {
  return ReceiptScanRepositoryImpl(ref.watch(receiptScanDatasourceProvider));
});

// Use case
final scanReceiptUseCaseProvider = Provider<ScanReceipt>((ref) {
  return ScanReceipt(ref.watch(receiptScanRepositoryProvider));
});

// Scan state
enum ScanStatus { idle, notSupported, scanning, success, error }

class ReceiptScanState {
  const ReceiptScanState({
    this.status = ScanStatus.idle,
    this.result,
    this.errorMessage,
  });

  final ScanStatus status;
  final ScanResultEntity? result;
  final String? errorMessage;

  ReceiptScanState copyWith({
    ScanStatus? status,
    ScanResultEntity? result,
    String? errorMessage,
  }) {
    return ReceiptScanState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }
}

class ReceiptScanNotifier extends StateNotifier<ReceiptScanState> {
  ReceiptScanNotifier(this._scanReceipt) : super(const ReceiptScanState());

  final ScanReceipt _scanReceipt;

  Future<void> scan(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    await _runScan(imageFile, language: language);
  }

  Future<void> _runScan(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    state = const ReceiptScanState(status: ScanStatus.scanning);

    final result = await _scanReceipt(imageFile: imageFile, language: language);

    state = result.fold(
      (failure) {
        if (failure is UnsupportedFeatureFailure) {
          return ReceiptScanState(
            status: ScanStatus.notSupported,
            errorMessage: failure.message,
          );
        }
        return ReceiptScanState(
          status: ScanStatus.error,
          errorMessage: failure.message,
        );
      },
      (scanResult) {
        if (scanResult.items.isEmpty && scanResult.total <= 0) {
          return const ReceiptScanState(
            status: ScanStatus.error,
            errorMessage: '無法辨識此圖片內容，請確認圖片清晰度後重試',
          );
        }
        return ReceiptScanState(status: ScanStatus.success, result: scanResult);
      },
    );
  }

  void reset() {
    state = const ReceiptScanState();
  }
}

final receiptScanProvider =
    StateNotifierProvider.autoDispose<ReceiptScanNotifier, ReceiptScanState>((
      ref,
    ) {
      return ReceiptScanNotifier(ref.watch(scanReceiptUseCaseProvider));
    });
