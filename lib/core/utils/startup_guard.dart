import 'dart:async';

import 'package:kawai_notes/core/utils/logger.dart';

/// Runs a best-effort pre-cache step (e.g. font download) without letting
/// a slow or offline network block app startup.
Future<void> precacheWithTimeout(
  Future<void> Function() pending, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    await pending().timeout(timeout);
  } catch (e) {
    AppLogger.instance.warning('Pre-cache skipped', e);
  }
}
