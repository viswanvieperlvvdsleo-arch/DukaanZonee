import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Real-time network connectivity service.
/// Polls actual internet reachability every 3 seconds using DNS lookup.
/// Broadcasts status via [onStatusChange] stream.
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  bool _started = false;

  /// Start listening to connectivity changes.
  void start() {
    if (_started) return;
    _started = true;
    _check(); // immediate first check
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  /// Stop the polling timer and close the stream.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<void> _check() async {
    final wasOnline = _isOnline;
    
    if (kIsWeb) {
      // dart:io InternetAddress lookup is native-only and throws on Web.
      // For web, we assume online by default unless implemented via package:http or js_interop.
      _isOnline = true;
    } else {
      try {
        final result = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 2));
        _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        _isOnline = false;
      }
    }

    if (_isOnline != wasOnline) {
      _controller.add(_isOnline);
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
