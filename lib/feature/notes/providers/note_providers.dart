import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/markdown_parser_extension.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';

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

class NotePreviewNotifier extends AsyncNotifier<String> {
  final String _contentPath;
  NotePreviewNotifier(this._contentPath);

  @override
  FutureOr<String> build() async {
    final repo = ref.read(noteRepositoryProvider);
    final content = await repo.readNoteContent(_contentPath);
    return content.toPlainText();
  }
}

final notePreviewProvider =
    AsyncNotifierProvider.family<NotePreviewNotifier, String, String>(
      NotePreviewNotifier.new,
    );
