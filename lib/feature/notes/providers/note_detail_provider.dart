import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/riverpod_extension.dart';
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

final noteDetailNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<NoteDetailNotifier, NoteDetailState, int?>(NoteDetailNotifier.new);

class NoteDetailNotifier extends AsyncNotifier<NoteDetailState> {
  final int? _id;

  NoteDetailNotifier(this._id);

  late NoteRepository _noteRepository;

  @override
  FutureOr<NoteDetailState> build() async {
    ref.cacheFor(const Duration(minutes: 5));

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
    bool? isPinned,
  }) async {
    final current = state.value;
    if (current == null) return;

    final hiddenStatus = isHidden ?? current.note?.isHidden ?? false;
    final pinnedStatus = isPinned ?? current.note?.isPinned ?? false;
    final folderTargetId = folderId ?? current.note?.folder.targetId ?? 0;

    // Check if anything actually changed
    final bool hasChanged =
        current.note == null ||
        current.note!.title != title ||
        current.content != content ||
        current.note!.isHidden != hiddenStatus ||
        current.note!.isPinned != pinnedStatus ||
        current.note!.folder.targetId != folderTargetId;

    if (!hasChanged) {
      return; // Skip saving to avoid updating `updatedAt`
    }

    state = AsyncData(
      current.copyWith(isMutating: true, mutationError: () => null),
    );

    try {
      await _noteRepository.saveNote(
        id: current.note?.id ?? 0,
        ulid: current.note?.ulid,
        title: title,
        content: content,
        folderId: folderTargetId == 0 ? null : folderTargetId,
        isHidden: hiddenStatus,
        isPinned: pinnedStatus,
        createdAt: current.note?.createdAt,
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
