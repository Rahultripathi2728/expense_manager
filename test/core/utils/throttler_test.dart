import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/utils/throttler.dart';

void main() {
  group('Throttler Tests', () {
    test('executes action only once within delay period', () async {
      final throttler = Throttler(delay: const Duration(milliseconds: 100));
      int callCount = 0;

      void action() {
        callCount++;
      }

      throttler.run(action);
      throttler.run(action);
      throttler.run(action);

      expect(callCount, 1);

      await Future.delayed(const Duration(milliseconds: 150));

      throttler.run(action);
      expect(callCount, 2);
    });

    test('dispose cancels the timer safely', () async {
      final throttler = Throttler(delay: const Duration(milliseconds: 100));
      int callCount = 0;

      void action() {
        callCount++;
      }

      throttler.run(action);
      expect(callCount, 1);
      
      throttler.dispose();
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Since it was disposed, the state does not automatically reset after the delay,
      // actually, dispose only cancels the timer. So _isReady stays false if we don't reset it.
      // The implementation leaves _isReady = false if cancelled before it runs.
      throttler.run(action);
      expect(callCount, 1); // should not be called again
    });
  });
}
