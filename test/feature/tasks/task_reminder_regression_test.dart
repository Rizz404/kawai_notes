import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/services/notification_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/tasks/providers/task_detail_provider.dart';
import 'package:kawai_notes/feature/tasks/providers/task_list_provider.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/objectbox_test_store.dart';

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late ObjectBoxTestStore testStore;
  late TaskRepository tasks;
  late MockNotificationService notifications;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(DateTime(2000)));

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    tasks = TaskRepository(testStore.service);
    notifications = MockNotificationService();
    when(
      () => notifications.scheduleNotification(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
      ),
    ).thenAnswer((_) async => ReminderScheduleResult.exact);
    when(() => notifications.cancelNotification(any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(tasks),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  DateTime tomorrow() => DateTime.now().add(const Duration(days: 1));

  Future<TaskDetailNotifier> detail(int? id) async {
    await container.read(taskDetailNotifierProvider(id).future);
    return container.read(taskDetailNotifierProvider(id).notifier);
  }

  test('F6a reopening "new task" starts empty and creates a second task', () async {
    final sub1 = container.listen(taskDetailNotifierProvider(null), (_, _) {});
    expect(await (await detail(null)).saveTask(title: 'First'), isTrue);
    sub1.close();
    await Future<void>.delayed(Duration.zero);

    final sub2 = container.listen(taskDetailNotifierProvider(null), (_, _) {});
    addTearDown(sub2.close);
    final reopened = await container.read(
      taskDetailNotifierProvider(null).future,
    );
    expect(reopened.data, isNull);
    await (await detail(null)).saveTask(title: 'Second');

    expect(
      tasks.getAllTasks().map((t) => t.title),
      unorderedEquals(['First', 'Second']),
    );
  });

  test('F6b editing a task keeps its createdAt', () async {
    final t = tasks.saveTask(title: 'a');
    final created = tasks.getTask(t.id)!.createdAt;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    tasks.saveTask(id: t.id, ulid: t.ulid, title: 'b');

    expect(tasks.getTask(t.id)!.createdAt, created);
    expect(tasks.getTask(t.id)!.title, 'b');
  });

  test('NEW-1 a due date schedules a reminder for the persisted task id', () async {
    final sub = container.listen(taskDetailNotifierProvider(null), (_, _) {});
    addTearDown(sub.close);
    final due = tomorrow();

    expect(await (await detail(null)).saveTask(title: 'Remind', dueDate: due), isTrue);

    final row = tasks.getAllTasks().single;
    verify(
      () => notifications.scheduleNotification(
        id: row.id,
        title: any(named: 'title'),
        body: 'Remind',
        scheduledDate: due,
      ),
    ).called(1);
  });

  test('F6c a scheduler failure does not duplicate the task on retry', () async {
    when(
      () => notifications.scheduleNotification(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
      ),
    ).thenThrow(Exception('exact alarm denied'));
    final sub = container.listen(taskDetailNotifierProvider(null), (_, _) {});
    addTearDown(sub.close);
    final n = await detail(null);

    await n.saveTask(title: 'X', dueDate: tomorrow());
    await n.saveTask(title: 'X', dueDate: tomorrow());

    expect(tasks.getAllTasks(), hasLength(1));
    expect(
      container.read(taskDetailNotifierProvider(null)).value?.data?.id,
      tasks.getAllTasks().single.id,
    );
  });

  test('F6d clearing the due date cancels the reminder', () async {
    final t = tasks.saveTask(title: 'T', dueDate: tomorrow());
    final sub = container.listen(taskDetailNotifierProvider(t.id), (_, _) {});
    addTearDown(sub.close);

    await (await detail(t.id)).saveTask(title: 'T');

    verify(() => notifications.cancelNotification(t.id)).called(1);
  });

  test('F6d completing a task cancels its reminder', () async {
    final t = tasks.saveTask(title: 'T', dueDate: tomorrow());
    await container.read(taskListNotifierProvider.future);

    await container.read(taskListNotifierProvider.notifier).toggleTaskCompletion(t.id);

    expect(tasks.getTask(t.id)!.isCompleted, isTrue);
    verify(() => notifications.cancelNotification(t.id)).called(1);
  });

  test('F12b un-completing a task with a future due date reschedules it',
      () async {
    // * ObjectBox stores dates at millisecond precision
    final due = DateTime.fromMillisecondsSinceEpoch(
      tomorrow().millisecondsSinceEpoch,
    );
    final t = tasks.saveTask(title: 'T', dueDate: due);
    await container.read(taskListNotifierProvider.future);
    final list = container.read(taskListNotifierProvider.notifier);

    await list.toggleTaskCompletion(t.id);
    await list.toggleTaskCompletion(t.id);

    expect(tasks.getTask(t.id)!.isCompleted, isFalse);
    verify(() => notifications.cancelNotification(t.id)).called(1);
    verify(
      () => notifications.scheduleNotification(
        id: t.id,
        title: any(named: 'title'),
        body: 'T',
        scheduledDate: due,
      ),
    ).called(1);
  });

  test('F12b un-completing a task without a due date schedules nothing',
      () async {
    final t = tasks.saveTask(title: 'T');
    await container.read(taskListNotifierProvider.future);
    final list = container.read(taskListNotifierProvider.notifier);

    await list.toggleTaskCompletion(t.id);
    await list.toggleTaskCompletion(t.id);

    verifyNever(
      () => notifications.scheduleNotification(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
      ),
    );
  });

  test('F6d deleting a task cancels its reminder', () async {
    final t = tasks.saveTask(title: 'T', dueDate: tomorrow());
    await container.read(taskListNotifierProvider.future);

    await container.read(taskListNotifierProvider.notifier).deleteTask(t.id);

    expect(tasks.getTask(t.id), isNull);
    verify(() => notifications.cancelNotification(t.id)).called(1);
  });

  test('NEW-1 the app router uses the global navigatorKey (l10n lookup)', () {
    expect(
      container.read(routerDelegateProvider).navigatorKey,
      same(navigatorKey),
    );
  });
}
