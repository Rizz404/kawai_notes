import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';

import '../../../support/objectbox_test_store.dart';

void main() {
  late ObjectBoxTestStore testStore;
  late TaskRepository repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = TaskRepository(testStore.service);
  });

  tearDown(() => testStore.close());

  test('saveTask persists a new task with a generated ulid', () {
    final task = repository.saveTask(title: 'Buy groceries');

    expect(task.id, isNot(0));
    expect(task.ulid, isNotEmpty);
    expect(task.isCompleted, isFalse);
    expect(repository.getTask(task.id)?.title, 'Buy groceries');
  });

  test('saveTask keeps the same ulid when updating an existing task', () {
    final created = repository.saveTask(title: 'Buy groceries');

    final updated = repository.saveTask(
      id: created.id,
      ulid: created.ulid,
      title: 'Buy groceries',
      isCompleted: true,
    );

    expect(updated.ulid, created.ulid);
    expect(repository.getAllTasks(), hasLength(1));
    expect(repository.getTask(created.id)?.isCompleted, isTrue);
  });

  test('getAllTasks returns every saved task', () {
    repository.saveTask(title: 'Task 1');
    repository.saveTask(title: 'Task 2');

    expect(repository.getAllTasks(), hasLength(2));
  });

  test('deleteTask removes the task', () {
    final task = repository.saveTask(title: 'Buy groceries');

    repository.deleteTask(task.id);

    expect(repository.getTask(task.id), isNull);
  });
}
