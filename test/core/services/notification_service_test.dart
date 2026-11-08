import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeDetails extends Fake implements NotificationDetails {}

void main() {
  late MockPlugin plugin;
  bool? canExact;
  late int requestCalls;
  late List<AndroidScheduleMode> modes;
  late List<int> shownIds;

  setUpAll(() {
    tzdata.initializeTimeZones();
    registerFallbackValue(_FakeDetails());
    registerFallbackValue(tz.TZDateTime.now(tz.UTC));
    registerFallbackValue(AndroidScheduleMode.exact);
  });

  setUp(() {
    plugin = MockPlugin();
    canExact = true;
    requestCalls = 0;
    modes = [];
    shownIds = [];
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).thenAnswer((inv) async {
      modes.add(inv.namedArguments[#androidScheduleMode] as AndroidScheduleMode);
    });
    when(
      () => plugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
      ),
    ).thenAnswer((inv) async {
      shownIds.add(inv.namedArguments[#id] as int);
    });
  });

  NotificationService service() => NotificationService(
    plugin: plugin,
    canScheduleExact: () async => canExact,
    requestExactPermission: () async {
      requestCalls++;
      canExact = true;
      return true;
    },
  );

  DateTime soon() => DateTime.now().add(const Duration(hours: 1));

  group('notification ids (F12a)', () {
    test('system notification ids are disjoint from task ids', () async {
      final svc = service();
      await svc.showBackupSuccessNotification(title: 't', body: 'b');
      await svc.showProgressNotification(
        id: NotificationService.importProgressId,
        title: 't',
        body: 'b',
        maxProgress: 1,
        progress: 0,
      );

      expect(shownIds, hasLength(2));
      // * ObjectBox task ids (used as reminder ids) are always >= 1
      for (final id in shownIds) {
        expect(id, lessThan(1));
      }
      expect(shownIds.toSet(), hasLength(2));
      expect(shownIds, isNot(contains(9001)));
    });
  });

  group('exact alarm permission (F12d)', () {
    test('granted: reminder is scheduled exactly', () async {
      final result = await service().scheduleNotification(
        id: 7,
        title: 't',
        body: 'b',
        scheduledDate: soon(),
      );

      expect(result, ReminderScheduleResult.exact);
      expect(modes, [AndroidScheduleMode.exactAllowWhileIdle]);
    });

    test('refused: reminder still fires, scheduled inexactly', () async {
      canExact = false;

      final result = await service().scheduleNotification(
        id: 7,
        title: 't',
        body: 'b',
        scheduledDate: soon(),
      );

      expect(result, ReminderScheduleResult.inexact);
      expect(modes, [AndroidScheduleMode.inexactAllowWhileIdle]);
      expect(requestCalls, 0, reason: 'scheduling never opens settings');
    });

    test('platform rejection of exact alarm falls back to inexact', () async {
      var first = true;
      when(
        () => plugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
        ),
      ).thenAnswer((inv) async {
        modes.add(
          inv.namedArguments[#androidScheduleMode] as AndroidScheduleMode,
        );
        if (first) {
          first = false;
          throw PlatformException(code: 'exact_alarms_not_permitted');
        }
      });

      final result = await service().scheduleNotification(
        id: 7,
        title: 't',
        body: 'b',
        scheduledDate: soon(),
      );

      expect(result, ReminderScheduleResult.inexact);
      expect(modes, [
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.inexactAllowWhileIdle,
      ]);
    });

    test('grant after refusal: next schedule is exact again', () async {
      canExact = false;
      final svc = service();
      expect(await svc.requestExactAlarmPermission(), isTrue);

      final result = await svc.scheduleNotification(
        id: 7,
        title: 't',
        body: 'b',
        scheduledDate: soon(),
      );

      expect(requestCalls, 1);
      expect(result, ReminderScheduleResult.exact);
    });

    test('past dates are skipped without touching the plugin', () async {
      final result = await service().scheduleNotification(
        id: 7,
        title: 't',
        body: 'b',
        scheduledDate: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(result, ReminderScheduleResult.skipped);
      expect(modes, isEmpty);
    });
  });
}
