import 'dart:io';

import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:slugify/slugify.dart';
import 'package:ulid/ulid.dart';

class NoteRepository {
  final ObjectBoxService _objectBoxService;
  final NoteFileService _noteFileService;
  final EncryptionService _encryptionService;

  /// Returns whether the hidden vault is unlocked for this session. Hidden
  /// content is never decrypted while it returns false.
  final bool Function() _isHiddenUnlocked;

  /// App documents directory; the only place owned note media may live.
  final Future<Directory> Function() _docsDir;

  NoteRepository(
    this._objectBoxService,
    this._noteFileService,
    this._encryptionService, {
    bool Function()? isHiddenUnlocked,
    Future<Directory> Function()? docsDir,
  }) : _isHiddenUnlocked = isHiddenUnlocked ?? _alwaysLocked,
       _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  static bool _alwaysLocked() => false;

  Future<void> migrateToSingleStorage() async {
    final box = _objectBoxService.store.box<Note>();
    final notes = box.getAll();

    // Read all content async BEFORE opening transaction (transactions are synchronous)
    final List<Note> toUpdate = [];
    for (final note in notes) {
      if (note.content == null) {
        // * raw file content: hidden notes stay encrypted at rest
        try {
          note.content = await _noteFileService.readNoteFile(note.contentPath);
          toUpdate.add(note);
        } catch (e, stack) {
          AppLogger.instance.error('Legacy note migration failed', e, stack);
        }
      }
    }

    if (toUpdate.isNotEmpty) {
      _objectBoxService.store.runInTransaction(TxMode.write, () {
        box.putMany(toUpdate);
      });
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

    final finalColor = customBackgroundImage == null ? colorValue : null;
    final finalBg = colorValue == null ? customBackgroundImage : null;

    // * update the stored entity in place so fields this call doesn't own
    // * (isDeleted, createdAt) are preserved
    final existing = id != 0 ? getNote(id) : null;
    final Note note;
    if (existing != null) {
      note = existing
        ..title = title
        ..contentPath = fileName
        ..content = finalContent
        ..tags = tags
        ..links = links
        ..isHidden = isHidden
        ..isPinned = isPinned
        ..colorValue = finalColor
        ..customBackgroundImage = finalBg
        ..updatedAt = updatedAt ?? DateTime.now();
      if (createdAt != null) note.createdAt = createdAt;
    } else {
      note = Note(
        id: id,
        ulid: noteUlid,
        title: title,
        contentPath: fileName,
        content: finalContent,
        tags: tags,
        links: links,
        isHidden: isHidden,
        isPinned: isPinned,
        colorValue: finalColor,
        customBackgroundImage: finalBg,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }

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
      return _decrypt(content);
    }
    return content;
  }

  /// Ambil content note langsung dari ObjectBox, decrypt jika hidden.
  ///
  /// Throws [DecryptionException] when a hidden note cannot be decrypted.
  Future<String> getNoteContent(Note note) async {
    final content = note.content ?? '';
    if (content.isEmpty) return '';

    if (note.isHidden) {
      final plain = await _decrypt(content);
      return _rebaseHiddenMedia(note, plain);
    }
    return content;
  }

  /// Hidden content is ciphertext at restore time, so its absolute image
  /// paths can only be rebased here, after a successful decrypt. A path is
  /// rewritten only when the same `images/...` file exists on this device;
  /// the note is re-encrypted without touching `updatedAt`.
  Future<String> _rebaseHiddenMedia(Note note, String plain) async {
    final Directory docs;
    try {
      docs = await _docsDir();
    } catch (_) {
      return plain;
    }
    final rebased = plain.replaceAllMapped(_markdownImageLink, (m) {
      final original = m.group(2)!;
      final parts = original.split(RegExp(r'[\\/]'));
      final idx = parts.lastIndexOf(_imagesDirName);
      if (idx < 0 || idx == parts.length - 1) return m.group(0)!;
      final rest = parts.sublist(idx + 1);
      if (rest.any((s) => s == '..' || s == '.' || s.isEmpty)) {
        return m.group(0)!;
      }
      final local = p.joinAll([docs.path, _imagesDirName, ...rest]);
      if (local == original ||
          FileSystemEntity.typeSync(local, followLinks: false) !=
              FileSystemEntityType.file) {
        return m.group(0)!;
      }
      return '${m.group(1)}$local${m.group(3)}';
    });
    if (rebased == plain) return plain;
    try {
      final stored = getNote(note.id);
      if (stored != null && stored.content == note.content) {
        stored.content = await _encryptionService.encrypt(rebased);
        _objectBoxService.store.box<Note>().put(stored);
        note.content = stored.content;
      }
    } catch (e, stack) {
      AppLogger.instance.error('Hidden media rebase write failed', e, stack);
    }
    return rebased;
  }

  Future<String> _decrypt(String ciphertext) async {
    if (!_isHiddenUnlocked()) throw const HiddenNotesLockedException();
    try {
      return await _encryptionService.decrypt(ciphertext);
    } on DecryptionException {
      rethrow;
    } catch (e) {
      throw DecryptionException(e);
    }
  }

  /// Moves a note into or out of the hidden vault, touching only the
  /// content encryption and the hidden flag. Throws [DecryptionException]
  /// (leaving the note unchanged) if a hidden note cannot be decrypted.
  Future<void> setNoteHidden(int id, {required bool isHidden}) async {
    final note = getNote(id);
    if (note == null || note.isHidden == isHidden) return;

    final raw = note.content ?? '';
    String content = raw;
    if (raw.isNotEmpty) {
      content = isHidden
          ? await _encryptionService.encrypt(raw)
          : await _decrypt(raw);
    }
    note
      ..content = content
      ..isHidden = isHidden
      ..updatedAt = DateTime.now();
    _objectBoxService.store.box<Note>().put(note);
  }

  /// Updates only the colour/background; content is never decrypted.
  Future<void> updateNoteBackground(
    int id, {
    int? colorValue,
    String? customBackgroundImage,
  }) async {
    final note = getNote(id);
    if (note == null) return;
    note
      ..colorValue = customBackgroundImage == null ? colorValue : null
      ..customBackgroundImage = colorValue == null
          ? customBackgroundImage
          : null
      ..updatedAt = DateTime.now();
    _objectBoxService.store.box<Note>().put(note);
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
      final owned = await _mediaRefs(note);
      _objectBoxService.store.box<Note>().remove(id);
      await _deleteUnreferencedMedia(owned);
    }
  }

  static final RegExp _markdownImagePath = RegExp(
    r'!\[[^\]]*\]\(([^)\s]+)\)',
  );
  static final RegExp _markdownImageLink = RegExp(
    r'(!\[[^\]]*\]\()([^)\s]+)(\))',
  );
  static const _imagesDirName = 'images';
  static const _bgFilePrefix = 'note_bg_';

  /// Media paths referenced by [note]. Hidden content that cannot be read
  /// right now (locked vault or undecryptable) is flagged as unreadable.
  Future<_MediaRefs> _mediaRefs(Note note) async {
    final images = <String>{};
    final bg = note.customBackgroundImage;
    final content = note.content ?? '';
    var readable = true;
    if (content.isNotEmpty) {
      String? plain = content;
      if (note.isHidden) {
        try {
          plain = await _decrypt(content);
        } catch (_) {
          plain = null;
          readable = false;
        }
      }
      if (plain != null) {
        for (final m in _markdownImagePath.allMatches(plain)) {
          images.add(p.normalize(m.group(1)!));
        }
      }
    }
    return _MediaRefs(
      images: images,
      background: bg == null ? null : p.normalize(bg),
      contentReadable: readable,
    );
  }

  /// Deletes media files of a removed note that no remaining note still
  /// references. Unreadable hidden notes conservatively retain every image.
  Future<void> _deleteUnreferencedMedia(_MediaRefs owned) async {
    final candidates = <String>{
      if (owned.contentReadable) ...owned.images,
      ?owned.background,
    };
    if (candidates.isEmpty) return;

    final referenced = <String>{};
    var keepAllImages = false;
    for (final other in getAllNotes()) {
      final refs = await _mediaRefs(other);
      referenced.addAll(refs.images);
      if (refs.background != null) referenced.add(refs.background!);
      if (!refs.contentReadable) keepAllImages = true;
    }

    final Directory docs;
    try {
      docs = await _docsDir();
    } catch (e, stack) {
      AppLogger.instance.error('Media cleanup: no docs dir', e, stack);
      return;
    }

    for (final path in candidates) {
      if (referenced.contains(path)) continue;
      final isBackground = path == owned.background;
      if (!isBackground && keepAllImages) continue;
      try {
        final file = _ownedMediaFile(path, docs);
        if (file != null) await file.delete();
      } catch (e, stack) {
        AppLogger.instance.error('Media cleanup failed', e, stack);
      }
    }
  }

  /// Returns the file at [path] only if it is a regular (non-symlink) file
  /// directly under `<docs>/images/` or a `note_bg_*` file directly in
  /// `<docs>/`, after resolving the real parent directory.
  File? _ownedMediaFile(String path, Directory docs) {
    if (!p.isAbsolute(path)) return null;
    final docsPath = p.normalize(docs.absolute.path);
    final parent = p.dirname(path);
    final name = p.basename(path);
    final String realExpectedParent;
    final realDocs = docs.resolveSymbolicLinksSync();
    if (parent == p.join(docsPath, _imagesDirName)) {
      realExpectedParent = p.join(realDocs, _imagesDirName);
    } else if (parent == docsPath && name.startsWith(_bgFilePrefix)) {
      realExpectedParent = realDocs;
    } else {
      return null;
    }
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type != FileSystemEntityType.file) return null;
    if (Directory(parent).resolveSymbolicLinksSync() != realExpectedParent) {
      return null;
    }
    return File(path);
  }

  /// Permanently deletes notes trashed more than [days] ago and returns
  /// their ids, so callers can reset widgets that showed them.
  Future<List<int>> cleanUpTrashNotes({int days = 30}) async {
    final threshold = DateTime.now().subtract(Duration(days: days));
    final trashNotes = _objectBoxService.store
        .box<Note>()
        .getAll()
        .where((n) => n.isDeleted && n.updatedAt.isBefore(threshold))
        .toList();

    for (final note in trashNotes) {
      await hardDeleteNote(note.id);
    }
    return [for (final note in trashNotes) note.id];
  }
}

class _MediaRefs {
  final Set<String> images;
  final String? background;
  final bool contentReadable;

  const _MediaRefs({
    required this.images,
    required this.background,
    required this.contentReadable,
  });
}
