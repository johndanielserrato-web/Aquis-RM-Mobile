import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void startMonitoring() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      if (connected != _isOnline) {
        _isOnline = connected;
        _controller.add(connected);
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
