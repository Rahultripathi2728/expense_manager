import 'dart:async';

class Throttler {
  final Duration delay;
  Timer? _timer;
  bool _isReady = true;

  Throttler({this.delay = const Duration(milliseconds: 500)});

  void run(void Function() action) {
    if (_isReady) {
      action();
      _isReady = false;
      _timer?.cancel();
      _timer = Timer(delay, () {
        _isReady = true;
      });
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
