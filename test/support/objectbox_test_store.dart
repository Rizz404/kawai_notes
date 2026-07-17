import 'dart:io';

import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/objectbox.g.dart';

/// Opens a throwaway ObjectBox store backed by a temp directory, so
/// repository/provider tests hit a real store without touching the app's DB.
class ObjectBoxTestStore {
  final ObjectBoxService service;
  final Directory _dir;

  ObjectBoxTestStore._(this.service, this._dir);

  static Future<ObjectBoxTestStore> open() async {
    final dir = Directory.systemTemp.createTempSync('kawai_notes_test_db_');
    final store = await openStore(directory: dir.path);
    return ObjectBoxTestStore._(ObjectBoxService.forTesting(store), dir);
  }

  void close() {
    service.store.close();
    if (_dir.existsSync()) {
      _dir.deleteSync(recursive: true);
    }
  }
}
