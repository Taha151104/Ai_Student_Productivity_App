import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) => QuizQuestion(
        question: map['question'] ?? '',
        options: List<String>.from(map['options'] ?? []),
        correctAnswer: map['correctAnswer'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options,
        'correctAnswer': correctAnswer,
      };
}

class QuizModel {
  final String quizId;
  final String noteId;
  final List<QuizQuestion> questions;
  final DateTime generatedAt;

  QuizModel({
    required this.quizId,
    required this.noteId,
    required this.questions,
    required this.generatedAt,
  });

  factory QuizModel.fromMap(String id, Map<String, dynamic> map) {
    return QuizModel(
      quizId: id,
      noteId: map['noteId'] ?? '',
      questions: (map['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      generatedAt: map['generatedAt'] is Timestamp
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'noteId': noteId,
        'questions': questions.map((q) => q.toMap()).toList(),
        'generatedAt': generatedAt,
      };
}
