import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/feature/folders/models/folder.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/objectbox.g.dart';

class FolderRepository {
  final ObjectBoxService _objectBoxService;

  FolderRepository(this._objectBoxService);

  Folder saveFolder({int id = 0, required String name, int? parentId}) {
    final folder = Folder(id: id, name: name, parentId: parentId);

    _objectBoxService.store.box<Folder>().put(folder);
    return folder;
  }

  List<Folder> getAllFolders() {
    return _objectBoxService.store.box<Folder>().getAll();
  }

  Folder? getFolder(int id) {
    return _objectBoxService.store.box<Folder>().get(id);
  }

  /// Deletes a folder without losing data: child folders move up to the
  /// deleted folder's parent and its notes become uncategorized.
  void deleteFolder(int id) {
    final store = _objectBoxService.store;
    final folderBox = store.box<Folder>();
    final noteBox = store.box<Note>();
    final folder = folderBox.get(id);
    if (folder == null) return;

    store.runInTransaction(TxMode.write, () {
      final children = folderBox
          .getAll()
          .where((f) => f.parentId == id)
          .toList();
      for (final child in children) {
        child.parentId = folder.parentId;
      }
      folderBox.putMany(children);

      final query = noteBox.query(Note_.folder.equals(id)).build();
      final notes = query.find();
      query.close();
      for (final note in notes) {
        note.folder.targetId = 0;
      }
      noteBox.putMany(notes);

      folderBox.remove(id);
    });
  }
}
