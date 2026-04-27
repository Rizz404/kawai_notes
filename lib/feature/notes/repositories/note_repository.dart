import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/objectbox.g.dart';
import 'package:slugify/slugify.dart';
import 'package:ulid/ulid.dart';

class NoteRepository {
  final ObjectBoxService _objectBoxService;
  final NoteFileService _noteFileService;
  final EncryptionService _encryptionService;

  NoteRepository(
    this._objectBoxService,
    this._noteFileService,
    this._encryptionService,
  );

  Future<void> migrateToSingleStorage() async {
    final box = _objectBoxService.store.box<Note>();
    final notes = box.getAll();

    for (final note in notes) {
      if (note.content == null) {
        final content = await readNoteContent(
          note.contentPath,
          isHidden: note.isHidden,
        );
        note.content = content;
        box.put(note);
      }
    }
  }

  Future<Note> saveNote({
    int id = 0,
    String? ulid,
    required String title,
    required String content,
    int? folderId,
    bool isHidden = false,
    bool isPinned = false,
    int? colorValue,
    String? customBackgroundImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final noteUlid = ulid ?? Ulid().toString();
    final slug = slugify(title);
    final fileName =
        '$slug-$noteUlid.md'; // Tetap simpan sebagai legacy reference

    // Parse markdown for tags & links from raw content BEFORE encryption
    final tags = content.extractTags();
    final links = content.extractLinks();

    // Encrypt if hidden
    String finalContent = content;
    if (isHidden) {
      finalContent = await _encryptionService.encrypt(content);
    }

    // Save to ObjectBox
    final note = Note(
      id: id,
      ulid: noteUlid,
      title: title,
      contentPath: fileName,
      content: finalContent,
      tags: tags,
      links: links,
      isHidden: isHidden,
      isPinned: isPinned,
      colorValue: customBackgroundImage == null ? colorValue : null,
      customBackgroundImage: colorValue == null ? customBackgroundImage : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    if (folderId != null) {
      note.folder.targetId = folderId;
    } else {
      note.folder.targetId = 0; // Detach
    }

    _objectBoxService.store.box<Note>().put(note);
    return note;
  }

  // ! Legacy — fallback ke file system, gunakan [getNoteContent] untuk akses langsung
  Future<String> readNoteContent(
    String contentPath, {
    bool isHidden = false,
  }) async {
    // Ambil note berdasarkan contentPath dari DB
    final query = _objectBoxService.store
        .box<Note>()
        .query(Note_.contentPath.equals(contentPath))
        .build();
    final note = query.findFirst();
    query.close();

    String content = '';
    if (note != null && note.content != null) {
      content = note.content!;
    } else {
      // Fallback ke file system jika di DB kosong
      content = await _noteFileService.readNoteFile(contentPath);
    }

    if (isHidden && content.isNotEmpty) {
      try {
        return await _encryptionService.decrypt(content);
      } catch (e) {
        return 'Error decrypting content: $e';
      }
    }
    return content;
  }

  /// Ambil content note langsung dari ObjectBox, decrypt jika hidden
  Future<String> getNoteContent(Note note) async {
    final content = note.content ?? '';
    if (content.isEmpty) return '';

    if (note.isHidden) {
      try {
        return await _encryptionService.decrypt(content);
      } catch (e) {
        return 'Error decrypting content: $e';
      }
    }
    return content;
  }

  List<Note> getAllNotes() {
    return _objectBoxService.store.box<Note>().getAll();
  }

  Note? getNote(int id) {
    return _objectBoxService.store.box<Note>().get(id);
  }

  Future<void> deleteNote(int id) async {
    final note = getNote(id);
    if (note != null) {
      note.isDeleted = true;
      note.updatedAt = DateTime.now();
      _objectBoxService.store.box<Note>().put(note);
    }
  }

  Future<void> restoreNote(int id) async {
    final note = getNote(id);
    if (note != null) {
      note.isDeleted = false;
      note.updatedAt = DateTime.now();
      _objectBoxService.store.box<Note>().put(note);
    }
  }

  Future<void> updateNotePin(int id, bool isPinned) async {
    final note = getNote(id);
    if (note != null) {
      note.isPinned = isPinned;
      _objectBoxService.store.box<Note>().put(note);
    }
  }

  Future<void> hardDeleteNote(int id) async {
    final note = getNote(id);
    if (note != null) {
      if (note.content == null) {
        // Hapus file legacy jika belum ter-migrate sepenuhnya
        await _noteFileService.deleteNoteFile(note.contentPath);
      }
      _objectBoxService.store.box<Note>().remove(id);
    }
  }

  Future<void> cleanUpTrashNotes({int days = 30}) async {
    final threshold = DateTime.now().subtract(Duration(days: days));
    final trashNotes = _objectBoxService.store
        .box<Note>()
        .getAll()
        .where((n) => n.isDeleted && n.updatedAt.isBefore(threshold))
        .toList();

    for (final note in trashNotes) {
      await hardDeleteNote(note.id);
    }
  }
}
