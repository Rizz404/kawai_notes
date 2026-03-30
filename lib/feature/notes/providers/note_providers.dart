import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'note_detail_provider.dart';
export 'note_list_provider.dart';

class IsGridViewNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final isGridViewProvider = NotifierProvider<IsGridViewNotifier, bool>(
  IsGridViewNotifier.new,
);
