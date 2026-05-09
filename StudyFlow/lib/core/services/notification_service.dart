import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const macos = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: ios,
          macOS: macos,
          linux: linux,
        ),
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> showSimple(String title, String body) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    if (!_initialized) return;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'studyflow_default',
          'StudyFlow',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleTaskReminder({
    required String title,
    DateTime? dueDate,
    String? dueTime,
    int minutesBefore = 10,
  }) async {
    if (kIsWeb || dueDate == null || dueTime == null || dueTime.length < 5) {
      return;
    }
    if (!_initialized) await init();
    if (!_initialized) return;

    final hour = int.tryParse(dueTime.substring(0, 2));
    final minute = int.tryParse(dueTime.substring(3, 5));
    if (hour == null || minute == null) return;

    final scheduledAt = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      hour,
      minute,
    ).subtract(Duration(minutes: minutesBefore));
    if (scheduledAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      scheduledAt.millisecondsSinceEpoch ~/ 1000,
      'StudyFlow',
      title,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'studyflow_tasks',
          'StudyFlow tasks',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
