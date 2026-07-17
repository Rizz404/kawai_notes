import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/tasks/providers/task_detail_provider.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';

import '../../../support/objectbox_test_store.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late ProviderContainer container;
  late TaskRepository repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = TaskRepository(testStore.service);
    container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  test('build with a null id starts an empty (create) state', () async {
    final state = await container.read(
      taskDetailNotifierProvider(null).future,
    );

    expect(state.data, isNull);
  });

  test('build with an existing id loads that task', () async {
    final task = repository.saveTask(title: 'Buy milk');

    final state = await container.read(
      taskDetailNotifierProvider(task.id).future,
    );

    expect(state.data?.title, 'Buy milk');
  });

  test('saveTask on a null id creates a new task', () async {
    await container.read(taskDetailNotifierProvider(null).future);

    final ok = await container
        .read(taskDetailNotifierProvider(null).notifier)
        .saveTask(title: 'New task');

    expect(ok, isTrue);
    expect(repository.getAllTasks().map((t) => t.title), contains('New task'));
  });

  test('saveTask on an existing id updates it in place, not a duplicate', () async {
    final task = repository.saveTask(title: 'Buy milk');
    await container.read(taskDetailNotifierProvider(task.id).future);

    await container
        .read(taskDetailNotifierProvider(task.id).notifier)
        .saveTask(title: 'Buy oat milk');

    expect(repository.getAllTasks(), hasLength(1));
    expect(repository.getTask(task.id)?.title, 'Buy oat milk');
  });

  test(
    'saveTask with a due date on an already-completed task skips notification scheduling',
    () async {
      final task = repository.saveTask(title: 'Done already', isCompleted: true);
      await container.read(taskDetailNotifierProvider(task.id).future);

      // isCompleted stays true via the repository default, so saveTask's
      // `dueDate != null && !task.isCompleted` guard must short-circuit
      // before it ever needs a live navigator context for notifications.
      final ok = await container
          .read(taskDetailNotifierProvider(task.id).notifier)
          .saveTask(
            title: 'Done already',
            dueDate: DateTime.now().add(const Duration(days: 1)),
          );

      expect(ok, isTrue);
    },
  );
}
