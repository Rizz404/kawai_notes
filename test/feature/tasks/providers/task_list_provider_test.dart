import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/tasks/models/task.dart';
import 'package:kawai_notes/feature/tasks/providers/task_list_provider.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';

import '../../../support/objectbox_test_store.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late ProviderContainer container;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(
          TaskRepository(testStore.service),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  test('build fetches tasks sorted by newest createdAt first', () async {
    final repo = container.read(taskRepositoryProvider);
    final older = repo.saveTask(title: 'Older');
    final box = testStore.service.store.box<Task>();
    box.put(
      box.get(older.id)!
        ..createdAt = DateTime.now().subtract(const Duration(days: 1)),
    );
    repo.saveTask(title: 'Newer');
    container.invalidate(taskListNotifierProvider);

    final state = await container.read(taskListNotifierProvider.future);

    expect(state.items.map((t) => t.title), ['Newer', 'Older']);
  });

  test('toggleTaskCompletion flips completion and refreshes state', () async {
    final repo = container.read(taskRepositoryProvider);
    final task = repo.saveTask(title: 'Buy milk');
    container.invalidate(taskListNotifierProvider);
    await container.read(taskListNotifierProvider.future);

    await container
        .read(taskListNotifierProvider.notifier)
        .toggleTaskCompletion(task.id);

    final state = container.read(taskListNotifierProvider).value!;
    expect(state.items.single.isCompleted, isTrue);
    expect(state.completedTasks, hasLength(1));
    expect(state.activeTasks, isEmpty);
  });

  test('deleteTask removes the task from state', () async {
    final repo = container.read(taskRepositoryProvider);
    final task = repo.saveTask(title: 'Buy milk');
    container.invalidate(taskListNotifierProvider);
    await container.read(taskListNotifierProvider.future);

    await container.read(taskListNotifierProvider.notifier).deleteTask(task.id);

    final state = container.read(taskListNotifierProvider).value!;
    expect(state.items, isEmpty);
    expect(state.isMutating, isFalse);
  });
}
