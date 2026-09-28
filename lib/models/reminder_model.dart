import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String reminderId;
  final String userId;
  final String taskTitle;
  final DateTime scheduledAt;
  final bool isCompleted;

  ReminderModel({
    required this.reminderId,
    required this.userId,
    required this.taskTitle,
    required this.scheduledAt,
    this.isCompleted = false,
  });

  factory ReminderModel.fromMap(String id, Map<String, dynamic> map) {
    return ReminderModel(
      reminderId: id,
      userId: map['userId'] ?? '',
      taskTitle: map['taskTitle'] ?? '',
      scheduledAt: map['scheduledAt'] is Timestamp
          ? (map['scheduledAt'] as Timestamp).toDate()
          : DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'taskTitle': taskTitle,
        'scheduledAt': scheduledAt,
        'isCompleted': isCompleted,
      };
}
