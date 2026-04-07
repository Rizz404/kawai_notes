import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/core/extensions/riverpod_extension.dart';
import 'package:kawai_notes/di/repository_providers.dart';

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
  final int _noteId;
  NotePreviewNotifier(this._noteId);

  @override
  FutureOr<String> build() async {
    ref.cacheFor(const Duration(minutes: 5));
    final repo = ref.read(noteRepositoryProvider);
    final note = repo.getNote(_noteId);
    if (note == null) return '';
    final content = await repo.readNoteContent(
      note.contentPath,
      isHidden: note.isHidden,
    );
    return content.toPlainText();
  }
}

final notePreviewProvider = AsyncNotifierProvider.autoDispose
    .family<NotePreviewNotifier, String, int>(NotePreviewNotifier.new);
