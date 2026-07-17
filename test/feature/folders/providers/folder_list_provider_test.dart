import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/folders/providers/folder_list_provider.dart';
import 'package:kawai_notes/feature/folders/repositories/folder_repository.dart';

import '../../../support/objectbox_test_store.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late ProviderContainer container;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    container = ProviderContainer(
      overrides: [
        folderRepositoryProvider.overrideWithValue(
          FolderRepository(testStore.service),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  test('build fetches all existing folders', () async {
    container.read(folderRepositoryProvider).saveFolder(name: 'Work');
    container.invalidate(folderListNotifierProvider);

    final state = await container.read(folderListNotifierProvider.future);

    expect(state.items.map((f) => f.name), ['Work']);
  });

  test('createFolder adds the folder and returns true', () async {
    await container.read(folderListNotifierProvider.future);

    final ok = await container
        .read(folderListNotifierProvider.notifier)
        .createFolder('Personal');

    expect(ok, isTrue);
    final state = container.read(folderListNotifierProvider).value!;
    expect(state.items.map((f) => f.name), ['Personal']);
    expect(state.isMutating, isFalse);
  });

  test('deleteFolder removes the folder from state', () async {
    final folder = container
        .read(folderRepositoryProvider)
        .saveFolder(name: 'Work');
    container.invalidate(folderListNotifierProvider);
    await container.read(folderListNotifierProvider.future);

    await container
        .read(folderListNotifierProvider.notifier)
        .deleteFolder(folder.id);

    final state = container.read(folderListNotifierProvider).value!;
    expect(state.items, isEmpty);
  });
}
