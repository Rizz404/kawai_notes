import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_widget_sync.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';

class NoteListState extends Equatable {
  final List<Note> items;
  final String query;
  final bool isMutating;
  final Object? mutationError;

  const NoteListState({
    this.items = const [],
    this.query = '',
    this.isMutating = false,
    this.mutationError,
  });

  bool get isEmpty => items.isEmpty;

  NoteListState copyWith({
    List<Note>? items,
    String? query,
    bool? isMutating,
    Object? Function()? mutationError,
  }) {
    return NoteListState(
      items: items ?? this.items,
      query: query ?? this.query,
      isMutating: isMutating ?? this.isMutating,
      mutationError: mutationError != null
          ? mutationError()
          : this.mutationError,
    );
  }

  @override
  List<Object?> get props => [items, query, isMutating, mutationError];
}

final noteListNotifierProvider =
    AsyncNotifierProvider<NoteListNotifier, NoteListState>(
      NoteListNotifier.new,
    );

class NoteListNotifier extends AsyncNotifier<NoteListState> {
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
        .where((n) => !n.isHidden && !n.isDeleted)
        .toList();

    allNotes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return b.isPinned ? 1 : -1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    List<Note> filtered = allNotes;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = allNotes.where((note) {
        if (note.title.toLowerCase().contains(q)) return true;
        if (note.tags.any((tag) => tag.toLowerCase().contains(q))) return true;
        // Notes here are non-hidden, so content field is plaintext — no decrypt needed
        return note.content?.toLowerCase().contains(q) ?? false;
      }).toList();
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

  Future<void> deleteNote(int id) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(isMutating: true, mutationError: () => null),
    );

    try {
      await _noteRepository.deleteNote(id);
      await syncNoteWidgets(ref, [id]);
      await _reload();
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
    }
  }

  Future<void> hideNotes(List<int> ids) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isMutating: true, mutationError: () => null));

    try {
      for (final id in ids) {
        await _noteRepository.setNoteHidden(id, isHidden: true);
      }
      await syncNoteWidgets(ref, ids);
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

  Future<void> pinNotes(List<int> ids, {required bool isPinned}) async {
    for (final id in ids) {
      await _noteRepository.updateNotePin(id, isPinned);
    }
    await _reload();
  }

  Future<void> batchUpdateBackground(
    List<int> ids, {
    int? colorValue,
    String? customBackgroundImage,
  }) async {
    for (final id in ids) {
      await _noteRepository.updateNoteBackground(
        id,
        colorValue: colorValue,
        customBackgroundImage: customBackgroundImage,
      );
    }
    await _reload();
  }
}
