import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/feature/folders/models/folder.dart';

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

  void deleteFolder(int id) {
    _objectBoxService.store.box<Folder>().remove(id);
  }
}
