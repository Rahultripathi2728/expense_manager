import 'dart:async';
import 'package:flutter/foundation.dart';

class Throttler {
  final int milliseconds;
  bool _isThrottling = false;
  Timer? _timer;

  Throttler({this.milliseconds = 2000}); // Default 2 seconds delay

  void run(VoidCallback action) {
    if (_isThrottling) return;
    
    action();
    _isThrottling = true;
    _timer = Timer(Duration(milliseconds: milliseconds), () {
      _isThrottling = false;
    });
  }

  void dispose() {
    _timer?.cancel();
    _isThrottling = false;
  }
}
