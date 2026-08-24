import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract final class RestNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    try {
      tz.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      _ready = true;
    } catch (error) {
      debugPrint('Rest notifications unavailable: $error');
    }
  }

  static Future<void> schedule({
    required String restId,
    required DateTime finishesAt,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_ready || !finishesAt.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _notificationId(restId),
      title: 'Rest complete',
      body: 'Your next set is ready.',
      scheduledDate: tz.TZDateTime.from(finishesAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer',
          'Rest timer',
          channelDescription: 'Alerts when a workout rest period finishes.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel(String restId) async {
    if (kIsWeb || !_ready) return;
    await _plugin.cancel(id: _notificationId(restId));
  }

  static int _notificationId(String restId) => restId.hashCode & 0x7fffffff;
}
