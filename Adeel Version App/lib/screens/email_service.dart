// lib/services/email_service.dart
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

Future<bool> sendDirectEmail(String studentMessage) async {
  if (studentMessage.trim().isEmpty) return false;

  final String username = 'bc230200766mta@vu.edu.pk';
  final String password = 'dzea pafj rytm zsfc'; // Your 16-letter App Password

  final smtpServer = gmail(username, password);

  final message = Message()
    ..from = Address(username, 'Student App Support')
    ..recipients.add('bc230200766mta@vu.edu.pk')
    ..subject = '🎯 New Student Support Ticket'
    ..text = 'A student left a message: $studentMessage'
    ..html =
        "<h3>New Support Request</h3><p><strong>Message:</strong> $studentMessage</p>";

  try {
    final sendReport = await send(message, smtpServer);
    print('Message sent: $sendReport');
    return true;
  } catch (e) {
    print('Message not sent. Error: $e');
    return false;
  }
}
