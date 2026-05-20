import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/feature/auth/providers/supabase_status_provider.dart';

/// Helper class to bridge Riverpod state changes to the RouterDelegate
class RouterRefreshListenable extends ChangeNotifier {
  final Ref ref;

  RouterRefreshListenable(this.ref) {
    // * Re-evaluate routes whenever Supabase session status changes
    ref.listen(supabaseStatusProvider, (_, _) => notifyListeners());
  }

  void triggerRefresh() {
    notifyListeners();
  }
}
