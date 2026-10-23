import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

final Map<int, Timer> _scheduledNotifications = {};

bool get webNotificationPermissionGranted =>
    web.Notification.permission == 'granted';

Future<bool> requestWebNotificationPermission() async {
  final permission = web.Notification.permission;
  if (permission == 'granted') return true;
  if (permission == 'denied') return false;
  return await web.Notification.requestPermission().toDart == 'granted';
}

void scheduleWebNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
}) {
  cancelWebNotification(id);
  final delay = scheduledDate.difference(DateTime.now());
  _scheduledNotifications[id] =
      Timer(delay.isNegative ? Duration.zero : delay, () {
    _scheduledNotifications.remove(id);
    if (web.Notification.permission == 'granted') {
      web.Notification(title, web.NotificationOptions(body: body));
    }
  });
}

void cancelWebNotification(int id) {
  _scheduledNotifications.remove(id)?.cancel();
}
