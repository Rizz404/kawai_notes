import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/core/extensions/riverpod_extension.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_detail_provider.dart';

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
    try {
      final content = await repo.getNoteContent(note);
      return content.toPlainText();
    } on DecryptionException {
      return '';
    }
  }
}

final notePreviewProvider = AsyncNotifierProvider.autoDispose
    .family<NotePreviewNotifier, String, int>(NotePreviewNotifier.new);

/// Drops the cached detail and preview of notes changed outside the editor
/// (hide/unhide, pin, colour), so a later edit starts from the stored note.
void invalidateNoteCaches(Ref ref, Iterable<int> ids) {
  for (final id in ids) {
    ref.invalidate(noteDetailNotifierProvider(id));
    ref.invalidate(notePreviewProvider(id));
  }
}
