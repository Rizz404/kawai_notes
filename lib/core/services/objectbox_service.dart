import 'package:flutter_setup_riverpod/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ObjectBoxService {
  late final Store store;

  ObjectBoxService._init(this.store);

  static Future<ObjectBoxService> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, "notes_db");
    final store = await openStore(directory: storePath);
    return ObjectBoxService._init(store);
  }
}
