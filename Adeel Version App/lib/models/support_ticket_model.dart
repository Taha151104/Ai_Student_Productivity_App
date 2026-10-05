import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicketModel {
  final String ticketId;
  final String userId;
  final String message;
  final String status; // 'Open', 'In Progress', 'Resolved'
  final DateTime createdAt;

  SupportTicketModel({
    required this.ticketId,
    required this.userId,
    required this.message,
    this.status = 'Open',
    required this.createdAt,
  });

  factory SupportTicketModel.fromMap(String id, Map<String, dynamic> map) {
    return SupportTicketModel(
      ticketId: id,
      userId: map['userId'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'Open',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'message': message,
        'status': status,
        'createdAt': createdAt,
      };
}
