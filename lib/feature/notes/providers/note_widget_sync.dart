import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/services/note_widget_service.dart';

/// Pushes the current state of the given notes to any home-screen widget
/// showing them. Best effort: a widget failure never fails the note action.
Future<void> syncNoteWidgets(Ref ref, Iterable<int> noteIds) async {
  try {
    final prefs = ref.read(sharedPreferencesProvider);
    final repo = ref.read(noteRepositoryProvider);
    for (final id in noteIds) {
      final note = repo.getNote(id);
      if (note == null) {
        await NoteWidgetService.clearWidgetsForNote(prefs: prefs, noteId: id);
        continue;
      }
      // * hidden notes are never decrypted for the widget
      final preview = note.isHidden ? '' : (note.content ?? '').toPlainText();
      await NoteWidgetService.refreshWidgetsForNote(
        prefs: prefs,
        note: note,
        contentPreview: preview,
      );
    }
  } catch (e, st) {
    ref.logError('Widget sync failed', e, st);
  }
}
