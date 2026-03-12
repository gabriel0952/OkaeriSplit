import 'package:app/core/services/connectivity_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  // Use the singleton that was already init()-ed in main().
  return ConnectivityService.instance;
});

/// Emits true when online, false when offline.
final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.isOnlineStream;
});

/// Synchronous online check — reads the latest value from the service.
final isOnlineProvider = Provider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  // Also listen to stream so we re-evaluate on change.
  ref.watch(connectivityProvider);
  return service.isOnline;
});
