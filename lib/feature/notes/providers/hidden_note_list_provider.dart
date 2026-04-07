import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_list_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';

final hiddenNoteListNotifierProvider =
    AsyncNotifierProvider<HiddenNoteListNotifier, NoteListState>(
      HiddenNoteListNotifier.new,
    );

class HiddenNoteListNotifier extends AsyncNotifier<NoteListState> {
  late NoteRepository _noteRepository;

  @override
  FutureOr<NoteListState> build() async {
    _noteRepository = ref.read(noteRepositoryProvider);
    return _fetch(query: '');
  }

  Future<NoteListState> _fetch({required String query}) async {
    final allNotes = _noteRepository
        .getAllNotes()
        .where((n) => n.isHidden && !n.isDeleted)
        .toList();

    List<Note> filtered = allNotes;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = allNotes.where((note) {
        return note.title.toLowerCase().contains(q) ||
            note.tags.any((tag) => tag.toLowerCase().contains(q));
      }).toList();
    }

    return NoteListState(items: filtered, query: query);
  }

  Future<void> search(String query) async {
    state = const AsyncLoading<NoteListState>();
    state = AsyncData(await _fetch(query: query));
  }

  Future<void> unhideNotes(List<int> ids) async {
    for (final id in ids) {
      final note = _noteRepository.getNote(id);
      if (note != null) {
        final content = await _noteRepository.readNoteContent(
          note.contentPath,
          isHidden: note.isHidden,
        );
        await _noteRepository.saveNote(
          id: note.id,
          ulid: note.ulid,
          title: note.title,
          content: content,
          folderId: note.folder.targetId,
          isHidden: false,
        );
      }
    }
    ref.invalidate(noteListNotifierProvider);
    ref.invalidateSelf();
  }

  Future<void> deleteNotes(List<int> ids) async {
    for (final id in ids) {
      await _noteRepository.deleteNote(id);
    }
    ref.invalidateSelf();
  }
}
