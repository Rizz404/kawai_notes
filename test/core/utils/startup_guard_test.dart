import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/utils/startup_guard.dart';

void main() {
  group('F9 font pre-cache must not block startup', () {
    test('never-completing font future finishes after timeout', () async {
      final never = Completer<void>().future;
      final sw = Stopwatch()..start();
      await precacheWithTimeout(
        () => never,
        timeout: const Duration(milliseconds: 200),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('failing font future does not throw (offline cold start)', () async {
      await expectLater(
        precacheWithTimeout(
          () => Future<void>.error(Exception('no network')),
          timeout: const Duration(seconds: 1),
        ),
        completes,
      );
    });

    test('fast success completes normally', () async {
      var called = false;
      await precacheWithTimeout(() async {
        called = true;
      }, timeout: const Duration(seconds: 1));
      expect(called, isTrue);
    });
  });
}
