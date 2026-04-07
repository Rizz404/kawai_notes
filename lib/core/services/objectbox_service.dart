import 'package:kawai_notes/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ObjectBoxService {
  Store store;

  ObjectBoxService._init(this.store);

  static Future<ObjectBoxService> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, 'notes_db');
    final store = await openStore(directory: storePath);
    return ObjectBoxService._init(store);
  }

  Future<void> restartStore() async {
    store.close();
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, 'notes_db');
    store = await openStore(directory: storePath);
  }
}
