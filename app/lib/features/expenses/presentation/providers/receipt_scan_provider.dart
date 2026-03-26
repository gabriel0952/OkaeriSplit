import 'dart:async';
import 'dart:io';

import 'package:app/core/providers/gemma_model_provider.dart';
import 'package:app/core/services/gemma_model_manager.dart';
import 'package:app/features/expenses/data/datasources/receipt_scan_datasource.dart';
import 'package:app/features/expenses/data/repositories/receipt_scan_repository_impl.dart';
import 'package:app/features/expenses/domain/entities/scan_result_entity.dart';
import 'package:app/features/expenses/domain/repositories/receipt_scan_repository.dart';
import 'package:app/features/expenses/domain/usecases/scan_receipt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Infrastructure
final receiptScanDatasourceProvider = Provider<ReceiptScanDatasource>((ref) {
  return ReceiptScanDatasource(ref.watch(gemmaModelManagerProvider));
});

final receiptScanRepositoryProvider = Provider<ReceiptScanRepository>((ref) {
  return ReceiptScanRepositoryImpl(ref.watch(receiptScanDatasourceProvider));
});

// Use case
final scanReceiptUseCaseProvider = Provider<ScanReceipt>((ref) {
  return ScanReceipt(ref.watch(receiptScanRepositoryProvider));
});

// Scan state
enum ScanStatus { idle, modelNotDownloaded, downloading, scanning, success, error }

class ReceiptScanState {
  const ReceiptScanState({
    this.status = ScanStatus.idle,
    this.result,
    this.errorMessage,
    this.downloadProgress = 0.0,
  });

  final ScanStatus status;
  final ScanResultEntity? result;
  final String? errorMessage;
  final double downloadProgress;

  ReceiptScanState copyWith({
    ScanStatus? status,
    ScanResultEntity? result,
    String? errorMessage,
    double? downloadProgress,
  }) {
    return ReceiptScanState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class ReceiptScanNotifier extends StateNotifier<ReceiptScanState> {
  ReceiptScanNotifier(this._scanReceipt, this._modelManager)
      : super(const ReceiptScanState());

  final ScanReceipt _scanReceipt;
  final GemmaModelManager _modelManager;
  StreamSubscription<ModelDownloadState>? _downloadSub;

  /// Initiates a scan. If the model isn't downloaded yet, transitions to
  /// [ScanStatus.modelNotDownloaded] so the UI can prompt the user.
  Future<void> scan(File imageFile) async {
    final isReady = await _modelManager.isModelDownloaded();
    if (!isReady) {
      state = const ReceiptScanState(status: ScanStatus.modelNotDownloaded);
      return;
    }
    await _runScan(imageFile);
  }

  /// Called when the user confirms downloading the model.
  /// Downloads the model with progress updates, then runs the scan.
  Future<void> downloadModelAndScan(File imageFile) async {
    state = const ReceiptScanState(
      status: ScanStatus.downloading,
      downloadProgress: 0.0,
    );

    _downloadSub?.cancel();
    _downloadSub = _modelManager.stateStream.listen((downloadState) {
      switch (downloadState) {
        case ModelDownloading(:final progress):
          state = state.copyWith(downloadProgress: progress);
        case ModelReady():
          _downloadSub?.cancel();
          _runScan(imageFile);
        case ModelDownloadError(:final message):
          _downloadSub?.cancel();
          state = ReceiptScanState(
            status: ScanStatus.error,
            errorMessage: '模型下載失敗：$message',
          );
        case ModelNotDownloaded():
          break;
      }
    });

    try {
      await _modelManager.downloadModel();
    } catch (e) {
      // Error already emitted via stateStream; no-op here.
    }
  }

  Future<void> _runScan(File imageFile) async {
    state = const ReceiptScanState(status: ScanStatus.scanning);

    final result = await _scanReceipt(imageFile: imageFile);

    state = result.fold(
      (failure) => ReceiptScanState(
        status: ScanStatus.error,
        errorMessage: failure.message,
      ),
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

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }
}

final receiptScanProvider =
    StateNotifierProvider.autoDispose<ReceiptScanNotifier, ReceiptScanState>((
  ref,
) {
  return ReceiptScanNotifier(
    ref.watch(scanReceiptUseCaseProvider),
    ref.watch(gemmaModelManagerProvider),
  );
});
