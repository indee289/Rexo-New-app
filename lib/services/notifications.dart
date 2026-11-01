import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/strings.dart';

/// Daily low-stock reminder, scheduled on the device. No push server.
///
/// Every call is guarded: a device that refuses to schedule (permission denied,
/// OEM battery policy) must degrade to "no reminder", never to a crash.
class Reminders {
  Reminders._();

  static const int _id = 1001;
  static const String _channelId = 'low_stock';
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // The audience is Indian shops; a single fixed zone avoids a plugin
      // dependency just to read the device zone name.
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel() async {
    try {
      await _plugin.cancel(_id);
    } catch (_) {
      // Nothing to do; an un-cancellable reminder is harmless.
    }
  }

  /// Schedules a repeating daily reminder. Returns false when the platform
  /// refused, so Settings can show the toggle as not actually active.
  static Future<bool> scheduleDaily({
    required int hour,
    required int minute,
    required int lowCount,
    required int outCount,
    required S s,
  }) async {
    await init();
    if (!_ready) return false;
    try {
      await cancel();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          s.reminder,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      await _plugin.zonedSchedule(
        _id,
        s.appName,
        '${s.low}: $lowCount   ${s.out}: $outCount',
        _nextOccurrence(hour, minute),
        details,
        // Inexact on purpose: exact alarms need a special Android permission
        // and a reminder that fires a few minutes late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }
}
