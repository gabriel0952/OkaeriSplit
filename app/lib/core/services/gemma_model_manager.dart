import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

/// Download state for Gemma3n E2B model.
sealed class ModelDownloadState {
  const ModelDownloadState();
}

class ModelNotDownloaded extends ModelDownloadState {
  const ModelNotDownloaded();
}

class ModelDownloading extends ModelDownloadState {
  const ModelDownloading(this.progress);
  final double progress; // 0.0 to 1.0
}

class ModelReady extends ModelDownloadState {
  const ModelReady();
}

class ModelDownloadError extends ModelDownloadState {
  const ModelDownloadError(this.message);
  final String message;
}

/// Manages the lifecycle of the on-device Gemma3n E2B model.
///
/// - Downloads via flutter_gemma's built-in install API on first use
/// - Exposes [stateStream] for reactive UI updates
class GemmaModelManager {
  GemmaModelManager._();
  static final instance = GemmaModelManager._();

  // The filename as saved by flutter_gemma (derived from the URL)
  static const _modelFileName = 'gemma-3n-E2B-it-int4.task';
  static const _modelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/resolve/main/gemma-3n-E2B-it-int4.task';

  // HuggingFace token injected at build time via --dart-define=HF_TOKEN=...
  static const _hfToken = String.fromEnvironment('HF_TOKEN', defaultValue: '');

  final _stateController =
      StreamController<ModelDownloadState>.broadcast();

  Stream<ModelDownloadState> get stateStream => _stateController.stream;
  ModelDownloadState _state = const ModelNotDownloaded();

  ModelDownloadState get currentState => _state;

  void _emit(ModelDownloadState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<bool> isModelDownloaded() async {
    return FlutterGemma.isModelInstalled(_modelFileName);
  }

  /// Downloads the model with progress reporting via [stateStream].
  Future<void> downloadModel() async {
    _emit(const ModelDownloading(0.0));
    try {
      final token = _hfToken.isNotEmpty ? _hfToken : null;

      await FlutterGemma.initialize(huggingFaceToken: token);

      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(_modelUrl, token: token)
          .withProgress((progress) {
            // progress is an int 0-100
            _emit(ModelDownloading((progress / 100.0).clamp(0.0, 1.0)));
          })
          .install();

      _emit(const ModelReady());
    } catch (e) {
      final msg = e.toString();
      _emit(ModelDownloadError(msg));
      rethrow;
    }
  }

  /// Returns an initialized [InferenceModel] ready for vision inference.
  /// Caller is responsible for calling [InferenceModel.close()] after use.
  Future<InferenceModel> getReadyModel() async {
    final installed = await isModelDownloaded();
    if (!installed) {
      throw StateError('Model not downloaded');
    }

    // Remove any stale XNNPack CPU cache left from previous runs.
    // The cache is regenerated automatically; stale/partial files can cause
    // mmap failures on low-memory devices.
    await _clearXnnpackCache();

    // Ensure FlutterGemma is initialized (no-op if already done)
    final token = _hfToken.isNotEmpty ? _hfToken : null;
    await FlutterGemma.initialize(huggingFaceToken: token);

    // Use GPU (Metal) backend to avoid XNNPack mmap overhead.
    // maxTokens kept small (128) — receipt JSON output is under 100 tokens.
    return FlutterGemma.getActiveModel(
      maxTokens: 128,
      supportImage: true,
      preferredBackend: PreferredBackend.gpu,
    );
  }

  Future<void> _clearXnnpackCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cache = File('${dir.path}/$_modelFileName.xnnpack_cache');
      if (await cache.exists()) {
        await cache.delete();
      }
    } catch (_) {
      // Cache deletion is best-effort; ignore errors.
    }
  }

  void dispose() {
    _stateController.close();
  }
}
