import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service_web_stub.dart'
    if (dart.library.html) 'notification_service_web.dart' as web_notifications;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get webNotificationPermissionGranted =>
      kIsWeb && web_notifications.webNotificationPermissionGranted;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // 1. Initialize timezone database
    tz.initializeTimeZones();

    // 2. Android notification icon setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // 3. Create high-priority notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'study_reminders_channel',
      'Study Reminders',
      description: 'Alerts and alarms when it is time to study',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      // Explicitly request Android 13+ runtime permissions & exact alarms
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Request permissions on-demand (called when user saves a plan)
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      return web_notifications.requestWebNotificationPermission();
    }

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a local study reminder at the exact date and time
  Future<void> scheduleStudyReminder({
    required int id,
    required String title,
    required String subject,
    required DateTime scheduledDate,
  }) async {
    await init();
    final permissionGranted = await requestPermissions();
    if (!permissionGranted) {
      throw StateError('Notification permission was not granted.');
    }

    // Prevent scheduling past dates
    if (scheduledDate.isBefore(DateTime.now())) {
      scheduledDate = DateTime.now().add(const Duration(seconds: 15));
    }

    final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);

    if (kIsWeb) {
      web_notifications.scheduleWebNotification(
        id: id,
        title: 'Study Time: $title',
        body: 'Time to study your $subject materials and notes!',
        scheduledDate: scheduledDate,
      );
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'study_reminders_channel',
      'Study Reminders',
      channelDescription: 'Alerts when it is time to study',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        '⏰ Study Time: $title',
        'Time to study your $subject materials and notes!',
        scheduledTz,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
          '✅ Notification #$id successfully scheduled for $scheduledDate');
    } catch (e) {
      debugPrint(
          'Schedule failed with exact alarm, falling back to inexact: $e');
      // Fallback if device restricts exact alarms
      await _notificationsPlugin.zonedSchedule(
        id,
        '⏰ Study Time: $title',
        'Time to study your $subject materials and notes!',
        scheduledTz,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelReminder(int id) async {
    if (kIsWeb) {
      web_notifications.cancelWebNotification(id);
      return;
    }
    await _notificationsPlugin.cancel(id);
  }
}
