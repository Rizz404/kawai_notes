import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:timezone/timezone.dart' as tz;

enum ReminderScheduleResult { exact, inexact, skipped }

class NotificationService {
  // * Task reminders use the task's ObjectBox id (always >= 1), so app-level
  // * notifications use non-positive ids and can never replace a reminder.
  static const backupSuccessId = -1;
  static const importProgressId = -2;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final Future<bool?> Function()? _canScheduleExact;
  final Future<bool?> Function()? _requestExactPermission;

  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<bool?> Function()? canScheduleExact,
    Future<bool?> Function()? requestExactPermission,
  }) : _flutterLocalNotificationsPlugin =
           plugin ?? FlutterLocalNotificationsPlugin(),
       _canScheduleExact = canScheduleExact,
       _requestExactPermission = requestExactPermission;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  /// Opens the system "Alarms & reminders" screen (Android 12+). Returns
  /// whether exact alarms are allowed afterwards.
  Future<bool> requestExactAlarmPermission() async {
    try {
      final request = _requestExactPermission;
      final granted = request != null
          ? await request()
          : await _android?.requestExactAlarmsPermission();
      return granted ?? true;
    } catch (e, stack) {
      AppLogger.instance.error('Exact alarm permission request failed', e, stack);
      return false;
    }
  }

  /// Null (non-Android / unknown) is treated as allowed.
  Future<bool> _exactAllowed() async {
    try {
      final check = _canScheduleExact;
      final allowed = check != null
          ? await check()
          : await _android?.canScheduleExactNotifications();
      return allowed ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    const androidInitializationSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  Future<ReminderScheduleResult> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Only schedule in future
    if (scheduledDate.isBefore(DateTime.now())) {
      return ReminderScheduleResult.skipped;
    }

    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for Task Deadlines',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final when = tz.TZDateTime.from(scheduledDate, tz.local);
    Future<void> schedule(AndroidScheduleMode mode) =>
        _flutterLocalNotificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: notificationDetails,
          androidScheduleMode: mode,
        );

    // * Without the exact-alarm grant (Android 12+ can refuse or revoke it)
    // * the reminder is still delivered, just inexactly.
    if (await _exactAllowed()) {
      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
        return ReminderScheduleResult.exact;
      } on PlatformException catch (e) {
        if (e.code != 'exact_alarms_not_permitted') rethrow;
      }
    }
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    return ReminderScheduleResult.inexact;
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> showBackupSuccessNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'backup_channel',
      'Auto Backup',
      channelDescription: 'Notifications for auto backup results',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      id: backupSuccessId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int maxProgress,
    required int progress,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'import_progress',
      'Import Progress',
      channelDescription: 'Notifications for bulk import progress',
      channelShowBadge: false,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      onlyAlertOnce: true,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
