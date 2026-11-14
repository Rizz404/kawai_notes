import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/riverpod_extension.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_widget_sync.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';

class NoteDetailState extends Equatable {
  final Note? note;
  final String content;
  final bool isMutating;
  final Object? mutationError;

  /// True when a hidden note's content could not be decrypted; the editor
  /// must stay read-only so the original ciphertext is never overwritten.
  final bool decryptFailed;

  const NoteDetailState({
    this.note,
    this.content = '',
    this.isMutating = false,
    this.mutationError,
    this.decryptFailed = false,
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
      decryptFailed: decryptFailed,
    );
  }

  @override
  List<Object?> get props => [
    note,
    content,
    isMutating,
    mutationError,
    decryptFailed,
  ];
}

final noteDetailNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<NoteDetailNotifier, NoteDetailState, int?>(NoteDetailNotifier.new);

class NoteDetailNotifier extends AsyncNotifier<NoteDetailState> {
  final int? _id;

  NoteDetailNotifier(this._id);

  late NoteRepository _noteRepository;

  @override
  FutureOr<NoteDetailState> build() async {
    // * hanya cache saat edit note yang sudah ada; create baru tidak di-cache
    // * agar setiap buka create screen selalu fresh (tanpa data note sebelumnya)
    if (_id != null) {
      ref.cacheFor(const Duration(minutes: 5));
    }

    _noteRepository = ref.read(noteRepositoryProvider);

    if (_id == null) {
      return const NoteDetailState(); // New note
    }

    final note = _noteRepository.getNote(_id);
    if (note == null) throw Exception('Note not found');

    try {
      final content = await _noteRepository.getNoteContent(note);
      return NoteDetailState(note: note, content: content);
    } on DecryptionException {
      return NoteDetailState(note: note, decryptFailed: true);
    }
  }

  Future<void> saveNote({
    required String title,
    required String content,
    int? folderId,
    bool? isHidden,
    bool? isPinned,
    int? colorValue,
    bool clearColor = false,
    String? customBackgroundImage,
    bool clearBackground = false,
  }) async {
    final current = state.value;
    if (current == null) return;
    // ! never write over ciphertext we could not decrypt
    if (current.decryptFailed) return;

    // ! the stored flag is authoritative: a cached snapshot taken before a
    // ! hide/unhide elsewhere must never move a note out of the vault
    final stored = current.note == null
        ? null
        : _noteRepository.getNote(current.note!.id);
    final hiddenStatus =
        isHidden ?? stored?.isHidden ?? current.note?.isHidden ?? false;
    final pinnedStatus = isPinned ?? current.note?.isPinned ?? false;
    final folderTargetId = folderId ?? current.note?.folder.targetId ?? 0;

    // * clear flags untuk reset eksplisit ke null
    final int? finalColorValue = clearColor
        ? null
        : (colorValue ?? current.note?.colorValue);
    final String? finalBgImage = clearBackground
        ? null
        : (customBackgroundImage ?? current.note?.customBackgroundImage);

    // Check if anything actually changed
    final bool hasChanged =
        current.note == null ||
        current.note!.title != title ||
        current.content != content ||
        current.note!.isHidden != hiddenStatus ||
        current.note!.isPinned != pinnedStatus ||
        current.note!.folder.targetId != folderTargetId ||
        current.note!.colorValue != finalColorValue ||
        current.note!.customBackgroundImage != finalBgImage;

    if (!hasChanged) {
      return; // Skip saving to avoid updating `updatedAt`
    }

    state = AsyncData(
      current.copyWith(isMutating: true, mutationError: () => null),
    );

    // * the editor pops before this finishes; without a keep-alive the
    // * autoDispose (create) provider is disposed mid-save and `state =` throws
    final keepAliveLink = ref.keepAlive();
    try {
      final savedNote = await _noteRepository.saveNote(
        id: current.note?.id ?? 0,
        ulid: current.note?.ulid,
        title: title,
        content: content,
        folderId: folderTargetId == 0 ? null : folderTargetId,
        isHidden: hiddenStatus,
        isPinned: pinnedStatus,
        colorValue: finalColorValue,
        customBackgroundImage: finalBgImage,
        createdAt: current.note?.createdAt,
      );

      // * update state dengan note terbaru agar ID tersimpan
      // * dan hasChanged akurat di save berikutnya (create → update, bukan create ulang)
      state = AsyncData(
        NoteDetailState(note: savedNote, content: content, isMutating: false),
      );

      await syncNoteWidgets(ref, [savedNote.id]);

      // * invalidate list agar urutan/data terbaru muncul
      ref.invalidate(noteListNotifierProvider);
      ref.invalidate(hiddenNoteListNotifierProvider);
      // * invalidate preview agar home screen menampilkan konten terbaru
      ref.invalidate(notePreviewProvider(savedNote.id));
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
    } finally {
      keepAliveLink.close();
    }
  }
}
