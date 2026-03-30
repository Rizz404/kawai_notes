import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension pada riverpod Ref untuk mempertahankan state secara cache dalam durasi tertentu.
extension CacheForExtension on Ref {
  /// Mempertahankan provider tetap hidup selama parameter [duration] sebelum di-dispose.
  void cacheFor(Duration duration) {
    final link = keepAlive();

    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}
