import 'package:app/core/services/gemma_model_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gemmaModelManagerProvider = Provider<GemmaModelManager>((ref) {
  final manager = GemmaModelManager.instance;
  ref.onDispose(manager.dispose);
  return manager;
});

final modelDownloadStateProvider = StreamProvider<ModelDownloadState>((ref) {
  return ref.watch(gemmaModelManagerProvider).stateStream;
});
