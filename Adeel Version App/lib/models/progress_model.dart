import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressModel {
  final String progressId;
  final String userId;
  final String quizId;
  final int score;
  final int totalQuestions;
  final DateTime recordedAt;

  ProgressModel({
    required this.progressId,
    required this.userId,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.recordedAt,
  });

  factory ProgressModel.fromMap(String id, Map<String, dynamic> map) {
    return ProgressModel(
      progressId: id,
      userId: map['userId'] ?? '',
      quizId: map['quizId'] ?? '',
      score: map['score'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      recordedAt: map['recordedAt'] is Timestamp
          ? (map['recordedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'quizId': quizId,
        'score': score,
        'totalQuestions': totalQuestions,
        'recordedAt': recordedAt,
      };
}
