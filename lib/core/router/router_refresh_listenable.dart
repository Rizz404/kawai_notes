import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helper class to bridge Riverpod state changes to the RouterDelegate
class RouterRefreshListenable extends ChangeNotifier {
  final Ref ref;

  RouterRefreshListenable(this.ref) {
    // Watch or listen to auth/user states here
    // Example: ref.listen(authProvider, (_, __) => notifyListeners());
  }

  void triggerRefresh() {
    notifyListeners();
  }
}
