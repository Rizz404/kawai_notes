import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NoteFileService {
  Future<Directory> _getNotesDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final notesDir = Directory(p.join(docsDir.path, 'notes'));
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  Future<File> saveNoteFile(
    String fileName,
    String content, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final dir = await _getNotesDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content);

    if (updatedAt != null || createdAt != null) {
      final modifyTime = updatedAt ?? createdAt!;
      await file.setLastModified(modifyTime);
      await file.setLastAccessed(modifyTime);
    }

    return file;
  }

  Future<String> readNoteFile(String fileName) async {
    final dir = await _getNotesDir();
    final file = File(p.join(dir.path, fileName));
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  Future<void> deleteNoteFile(String fileName) async {
    final dir = await _getNotesDir();
    final file = File(p.join(dir.path, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
