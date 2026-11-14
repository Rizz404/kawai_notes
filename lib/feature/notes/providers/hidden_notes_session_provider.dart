import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clock used by the hidden-notes session; overridable in tests.
final hiddenNotesClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Whether the hidden-notes vault has been unlocked in this app session.
///
/// This notifier is the single owner of lifecycle locking: the app forwards
/// every lifecycle change to [handleLifecycle]. Screens never lock on pause
/// themselves. The router reacts to a lock by removing every vault page.
/// System UI the app opens on purpose (image picker, biometric prompt) runs
/// through [runTransient] and does not lock unless it outlasts
/// [transientGrace].
class HiddenNotesSessionNotifier extends Notifier<bool> {
  static const transientGrace = Duration(minutes: 2);

  int _transientDepth = 0;
  DateTime? _transientPausedAt;
  Timer? _graceTimer;

  @override
  bool build() {
    ref.onDispose(() => _graceTimer?.cancel());
    return false;
  }

  DateTime _now() => ref.read(hiddenNotesClockProvider)();

  void unlock() => state = true;

  void lock() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _transientPausedAt = null;
    if (ref.mounted) state = false;
  }

  void handleLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
        if (_transientDepth > 0) {
          if (_transientPausedAt == null) {
            _transientPausedAt = _now();
            // * the grace also expires while the app stays in the background
            _graceTimer = Timer(transientGrace, lock);
          }
        } else {
          lock();
        }
      case AppLifecycleState.detached:
        lock();
      case AppLifecycleState.resumed:
        _graceTimer?.cancel();
        _graceTimer = null;
        final pausedAt = _transientPausedAt;
        _transientPausedAt = null;
        if (pausedAt == null) return;
        final away = _now().difference(pausedAt);
        // * a clock that moved backwards cannot extend the grace
        if (away.isNegative || away > transientGrace) lock();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Runs [action], which opens system UI that briefly backgrounds the app,
  /// without locking the vault for pauses shorter than [transientGrace].
  ///
  /// A pause that started inside [action] is only settled by the real
  /// `resumed` event (or the grace timer), even if [action] completes while
  /// the app is still in the background, so the full time away is measured.
  Future<T> runTransient<T>(Future<T> Function() action) async {
    _transientDepth++;
    try {
      return await action();
    } finally {
      _transientDepth--;
    }
  }
}

final hiddenNotesSessionProvider =
    NotifierProvider<HiddenNotesSessionNotifier, bool>(
      HiddenNotesSessionNotifier.new,
    );
