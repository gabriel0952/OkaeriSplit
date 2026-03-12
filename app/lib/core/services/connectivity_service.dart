import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Singleton — main.dart calls init() on this instance before runApp,
  // so providers always share the same pre-initialized state.
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _connectivity = Connectivity();
  bool _isOnline = true; // will be overwritten by init() before first use

  bool get isOnline => _isOnline;

  Stream<bool> get isOnlineStream =>
      _connectivity.onConnectivityChanged.map(_resultsToOnline);

  /// Must be called once in main() before runApp().
  /// Checks real connectivity and starts listening for changes.
  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _resultsToOnline(results);
    _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = _resultsToOnline(results);
    });
  }

  static bool _resultsToOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
