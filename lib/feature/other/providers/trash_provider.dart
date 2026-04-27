import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';

final trashListNotifierProvider =
    AsyncNotifierProvider.autoDispose<TrashListNotifier, List<Note>>(
      TrashListNotifier.new,
    );

class TrashListNotifier extends AsyncNotifier<List<Note>> {
  @override
  FutureOr<List<Note>> build() async {
    final repo = ref.read(noteRepositoryProvider);
    final allNotes = repo.getAllNotes();
    final trashNotes = allNotes.where((n) => n.isDeleted).toList();

    trashNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return trashNotes;
  }

  Future<void> restoreNote(int id) async {
    await ref.read(noteRepositoryProvider).restoreNote(id);
    ref.invalidate(noteListNotifierProvider);
    ref.invalidateSelf();
  }

  Future<void> emptyTrash() async {
    final notes = state.value ?? [];
    for (final note in notes) {
      await ref.read(noteRepositoryProvider).hardDeleteNote(note.id);
    }
    ref.invalidateSelf();
  }

  Future<void> deletePermanently(int id) async {
    await ref.read(noteRepositoryProvider).hardDeleteNote(id);
    ref.invalidateSelf();
  }
}
