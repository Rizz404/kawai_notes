import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
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

  Future<void> deleteNote(int id) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(isMutating: true, mutationError: () => null),
    );

    try {
      await _noteRepository.deleteNote(id);
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
    }
  }

  Future<void> hideNotes(List<int> ids) async {
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
          isHidden: true,
        );
      }
    }
    ref.invalidateSelf();
  }

  Future<void> deleteNotes(List<int> ids) async {
    for (final id in ids) {
      await _noteRepository.deleteNote(id);
    }
    ref.invalidateSelf();
  }
}
