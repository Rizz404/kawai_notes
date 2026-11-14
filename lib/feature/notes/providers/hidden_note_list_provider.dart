import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_widget_sync.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';

final hiddenNoteListNotifierProvider =
    AsyncNotifierProvider<HiddenNoteListNotifier, NoteListState>(
      HiddenNoteListNotifier.new,
    );

class HiddenNoteListNotifier extends AsyncNotifier<NoteListState> {
  late NoteRepository _noteRepository;
  int _searchGeneration = 0;

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
      final List<Note> matchedNotes = [];
      for (final note in allNotes) {
        bool isMatch =
            note.title.toLowerCase().contains(q) ||
            note.tags.any((tag) => tag.toLowerCase().contains(q));

        if (!isMatch) {
          try {
            final content = await _noteRepository.getNoteContent(note);
            if (content.toLowerCase().contains(q)) {
              isMatch = true;
            }
          } catch (e) {
            logError('Failed to read note content for search: ${note.id}', e);
          }
        }

        if (isMatch) {
          matchedNotes.add(note);
        }
      }
      filtered = matchedNotes;
    }

    return NoteListState(items: filtered, query: query);
  }

  // * Re-reads the list but keeps the active search query (invalidateSelf
  // * would rebuild with an empty query and drop the user's filter).
  Future<void> _reload() async {
    final query = state.value?.query ?? '';
    state = AsyncData(await _fetch(query: query));
  }

  Future<void> search(String query) async {
    final generation = ++_searchGeneration;
    state = const AsyncLoading<NoteListState>();
    final result = await _fetch(query: query);
    if (generation == _searchGeneration) {
      state = AsyncData(result);
    }
  }

  Future<void> unhideNotes(List<int> ids) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isMutating: true, mutationError: () => null));

    try {
      Object? firstError;
      for (final id in ids) {
        try {
          await _noteRepository.setNoteHidden(id, isHidden: false);
        } on DecryptionException catch (e) {
          // ! undecryptable notes stay hidden with their ciphertext intact
          logError('Unhide skipped, note cannot be decrypted: $id', e);
          firstError ??= e;
        }
      }
      invalidateNoteCaches(ref, ids);
      await syncNoteWidgets(ref, ids);
      ref.invalidate(noteListNotifierProvider);
      if (firstError != null) {
        final refreshed = await _fetch(query: current.query);
        state = AsyncData(
          refreshed.copyWith(mutationError: () => firstError),
        );
        return;
      }
      await _reload();
    } catch (e) {
      state = AsyncData(current.copyWith(isMutating: false, mutationError: () => e));
    }
  }

  Future<void> deleteNotes(List<int> ids) async {
    for (final id in ids) {
      await _noteRepository.deleteNote(id);
    }
    await syncNoteWidgets(ref, ids);
    await _reload();
  }
}
