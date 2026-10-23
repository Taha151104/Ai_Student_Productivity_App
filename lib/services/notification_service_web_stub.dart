Future<bool> requestWebNotificationPermission() async => false;

bool get webNotificationPermissionGranted => false;

void scheduleWebNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
}) {
  throw UnsupportedError('Browser notifications are only available on web.');
}

void cancelWebNotification(int id) {}
