import 'package:flutter_local_ai/flutter_local_ai.dart';

/// Device availability state for system LLM.
sealed class ModelDownloadState {
  const ModelDownloadState();
}

class ModelNotSupported extends ModelDownloadState {
  const ModelNotSupported();
}

class ModelReady extends ModelDownloadState {
  const ModelReady();
}

class ModelDownloadError extends ModelDownloadState {
  const ModelDownloadError(this.message);
  final String message;
}

/// Wraps [FlutterLocalAi] (Apple Foundation Models / Android ML Kit GenAI).
///
/// No model download required — uses the system-provided LLM.
/// Supports iOS 18.1+ (A17 Pro+) and Android AICore devices.
class GemmaModelManager {
  GemmaModelManager._();
  static final instance = GemmaModelManager._();

  /// Returns true if the device supports on-device LLM inference.
  Future<bool> isAvailable() async {
    return FlutterLocalAi().isAvailable();
  }

  /// Returns an initialized [FlutterLocalAi] instance ready for inference.
  /// Caller should not call close() — the instance is stateless per call.
  Future<FlutterLocalAi> getReadyModel() async {
    final ai = FlutterLocalAi();
    await ai.initialize();
    return ai;
  }

  void dispose() {}
}
