import 'package:cloud_firestore/cloud_firestore.dart';

/// Safely converts a Firestore value to DateTime.
/// Firestore stores DateTime fields as [Timestamp], not [DateTime], so a
/// direct `as DateTime` cast throws at runtime.
DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

class ChatMessage {
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        sender: map['sender'] ?? 'user',
        text: map['text'] ?? '',
        timestamp: _toDateTime(map['timestamp']),
      );

  Map<String, dynamic> toMap() => {
        'sender': sender,
        'text': text,
        'timestamp': timestamp,
      };
}

class ChatSessionModel {
  final String sessionId;
  final String userId;
  final List<ChatMessage> messages;
  final DateTime startedAt;

  ChatSessionModel({
    required this.sessionId,
    required this.userId,
    required this.messages,
    required this.startedAt,
  });

  factory ChatSessionModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatSessionModel(
      sessionId: id,
      userId: map['userId'] ?? '',
      messages: (map['messages'] as List<dynamic>? ?? [])
          .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
          .toList(),
      startedAt: _toDateTime(map['startedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'messages': messages.map((m) => m.toMap()).toList(),
        'startedAt': startedAt,
      };
}
