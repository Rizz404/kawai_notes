import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class NoteFileService {
  Future<Directory> _getNotesDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final notesDir = Directory(p.join(docsDir.path, 'notes'));
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    return notesDir;
  }

  Future<File> saveNoteFile(String fileName, String content) async {
    final dir = await _getNotesDir();
    final file = File(p.join(dir.path, fileName));
    return await file.writeAsString(content);
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
