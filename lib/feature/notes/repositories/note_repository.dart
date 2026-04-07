import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
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

  Future<Note> saveNote({
    int id = 0,
    String? ulid,
    required String title,
    required String content,
    int? folderId,
    bool isHidden = false,
    bool isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final noteUlid = ulid ?? Ulid().toString();
    final slug = slugify(title);
    final fileName = '$slug-$noteUlid.md';

    // Parse markdown for tags & links from raw content BEFORE encryption
    final tags = content.extractTags();
    final links = content.extractLinks();

    // Encrypt if hidden
    String fileContent = content;
    if (isHidden) {
      fileContent = await _encryptionService.encrypt(content);
    }

    // Save actual file
    await _noteFileService.saveNoteFile(
      fileName,
      fileContent,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    // Save to ObjectBox
    final note = Note(
      id: id,
      ulid: noteUlid,
      title: title,
      contentPath: fileName,
      tags: tags,
      links: links,
      isHidden: isHidden,
      isPinned: isPinned,
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

  Future<String> readNoteContent(
    String contentPath, {
    bool isHidden = false,
  }) async {
    final content = await _noteFileService.readNoteFile(contentPath);
    if (isHidden && content.isNotEmpty) {
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

  Future<void> hardDeleteNote(int id) async {
    final note = getNote(id);
    if (note != null) {
      await _noteFileService.deleteNoteFile(note.contentPath);
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
