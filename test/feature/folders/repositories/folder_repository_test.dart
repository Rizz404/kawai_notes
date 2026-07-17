import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/folders/repositories/folder_repository.dart';

import '../../../support/objectbox_test_store.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late FolderRepository repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = FolderRepository(testStore.service);
  });

  tearDown(() => testStore.close());

  test('saveFolder persists a new folder and assigns an id', () {
    final folder = repository.saveFolder(name: 'Work');

    expect(folder.id, isNot(0));
    expect(repository.getFolder(folder.id)?.name, 'Work');
  });

  test('saveFolder with an existing id updates that folder', () {
    final created = repository.saveFolder(name: 'Work');

    final updated = repository.saveFolder(id: created.id, name: 'Personal');

    expect(updated.id, created.id);
    expect(repository.getAllFolders(), hasLength(1));
    expect(repository.getFolder(created.id)?.name, 'Personal');
  });

  test('getAllFolders returns every saved folder', () {
    repository.saveFolder(name: 'Work');
    repository.saveFolder(name: 'Personal');

    expect(repository.getAllFolders(), hasLength(2));
  });

  test('getFolder returns null for an unknown id', () {
    expect(repository.getFolder(999), isNull);
  });

  test('deleteFolder removes the folder', () {
    final folder = repository.saveFolder(name: 'Work');

    repository.deleteFolder(folder.id);

    expect(repository.getFolder(folder.id), isNull);
  });
}
