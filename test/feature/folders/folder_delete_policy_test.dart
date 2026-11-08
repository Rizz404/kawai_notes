import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/folders/models/folder.dart';
import 'package:kawai_notes/feature/folders/repositories/folder_repository.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/objectbox.g.dart';

import '../../support/objectbox_test_store.dart';

/// F7 delete policy: deleting a folder must not orphan child folders or
/// leave notes pointing at it. Notes are never deleted with the folder.
void main() {
  late ObjectBoxTestStore testStore;
  late FolderRepository repo;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repo = FolderRepository(testStore.service);
  });

  tearDown(() => testStore.close());

  test('children are re-parented to the deleted folder parent', () {
    final root = repo.saveFolder(name: 'root');
    final mid = repo.saveFolder(name: 'mid', parentId: root.id);
    final leaf = repo.saveFolder(name: 'leaf', parentId: mid.id);
    final top = repo.saveFolder(name: 'top-child', parentId: null);

    repo.deleteFolder(mid.id);

    expect(repo.getFolder(mid.id), isNull);
    expect(repo.getFolder(leaf.id)!.parentId, root.id);
    expect(repo.getFolder(top.id)!.parentId, isNull);
  });

  test('notes in the folder survive and become uncategorized', () {
    final f = repo.saveFolder(name: 'work');
    final box = testStore.service.store.box<Note>();
    final note = Note(title: 'n', ulid: 'u1', contentPath: 'n.md')..folder.targetId = f.id;
    box.put(note);

    repo.deleteFolder(f.id);

    final after = box.get(note.id)!;
    expect(after.folder.targetId, 0);
    // * no stored row may still reference the deleted folder id
    final stale = box.query(Note_.folder.equals(f.id)).build();
    expect(stale.count(), 0);
    stale.close();
    expect(box.count(), 1);
    expect(testStore.service.store.box<Folder>().count(), 0);
  });
}
