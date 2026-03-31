import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/models/note.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_list_provider.dart';
import 'package:flutter_setup_riverpod/feature/notes/repositories/note_repository.dart';

class NoteDetailState extends Equatable {
  final Note? note;
  final String content;
  final bool isMutating;
  final Object? mutationError;

  const NoteDetailState({
    this.note,
    this.content = '',
    this.isMutating = false,
    this.mutationError,
  });

  NoteDetailState copyWith({
    Note? Function()? note,
    String? content,
    bool? isMutating,
    Object? Function()? mutationError,
  }) {
    return NoteDetailState(
      note: note != null ? note() : this.note,
      content: content ?? this.content,
      isMutating: isMutating ?? this.isMutating,
      mutationError: mutationError != null
          ? mutationError()
          : this.mutationError,
    );
  }

  @override
  List<Object?> get props => [note, content, isMutating, mutationError];
}

final noteDetailNotifierProvider =
    AsyncNotifierProvider.family<NoteDetailNotifier, NoteDetailState, int?>(
      NoteDetailNotifier.new,
    );

class NoteDetailNotifier extends AsyncNotifier<NoteDetailState> {
  final int? _id;

  NoteDetailNotifier(this._id);

  late NoteRepository _noteRepository;

  @override
  FutureOr<NoteDetailState> build() async {
    _noteRepository = ref.read(noteRepositoryProvider);

    if (_id == null) {
      return const NoteDetailState(); // New note
    }

    final note = _noteRepository.getNote(_id);
    if (note == null) throw Exception('Note not found');

    final content = await _noteRepository.readNoteContent(
      note.contentPath,
      isHidden: note.isHidden,
    );

    return NoteDetailState(note: note, content: content);
  }

  Future<void> saveNote({
    required String title,
    required String content,
    int? folderId,
    bool? isHidden,
  }) async {
    final current = state.value;
    if (current == null) return;

    final hiddenStatus = isHidden ?? current.note?.isHidden ?? false;

    state = AsyncData(
      current.copyWith(isMutating: true, mutationError: () => null),
    );

    try {
      await _noteRepository.saveNote(
        id: current.note?.id ?? 0,
        ulid: current.note?.ulid,
        title: title,
        content: content,
        folderId: folderId,
        isHidden: hiddenStatus,
      );

      ref.invalidate(noteListNotifierProvider);
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
    }
  }
}
