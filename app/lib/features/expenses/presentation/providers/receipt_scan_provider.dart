import 'dart:io';

import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/data/datasources/gemini_receipt_scan_datasource.dart';
import 'package:app/core/errors/failures.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/domain/entities/receipt_scan_method.dart';
import 'package:app/features/expenses/data/repositories/receipt_scan_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';
import 'package:app/features/expenses/domain/usecases/scan_receipt.dart';
import 'package:app/features/expenses/presentation/providers/gemini_scan_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final localReceiptScanDatasourceProvider = Provider<ReceiptScanDatasource>((
  ref,
) {
  return ReceiptScanDatasource();
});

final geminiReceiptScanDatasourceProvider =
    Provider<GeminiReceiptScanDatasource>((ref) {
      return GeminiReceiptScanDatasource(ref.watch(supabaseClientProvider));
    });

final receiptScanRepositoryProvider = Provider<ReceiptScanRepository>((ref) {
  return ReceiptScanRepositoryImpl(
    ref.watch(localReceiptScanDatasourceProvider),
    ref.watch(geminiReceiptScanDatasourceProvider),
    ref.watch(geminiScanSettingsDatasourceProvider),
  );
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
    ReceiptScanMethod method = ReceiptScanMethod.local,
    String? userId,
  }) async {
    await _runScan(
      imageFile,
      language: language,
      method: method,
      userId: userId,
    );
  }

  Future<void> _runScan(
    File imageFile, {
    OcrLanguage language = OcrLanguage.auto,
    ReceiptScanMethod method = ReceiptScanMethod.local,
    String? userId,
  }) async {
    state = const ReceiptScanState(status: ScanStatus.scanning);

    final result = await _scanReceipt(
      imageFile: imageFile,
      language: language,
      method: method,
      userId: userId,
    );

    state = result.fold(
      (failure) {
        if (failure is UnsupportedFeatureFailure &&
            method == ReceiptScanMethod.local) {
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
