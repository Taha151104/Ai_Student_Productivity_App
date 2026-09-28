import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardModel {
  final String flashcardId;
  final String noteId;
  final String frontText;
  final String backText;
  final DateTime generatedAt;

  FlashcardModel({
    required this.flashcardId,
    required this.noteId,
    required this.frontText,
    required this.backText,
    required this.generatedAt,
  });

  factory FlashcardModel.fromMap(String id, Map<String, dynamic> map) {
    return FlashcardModel(
      flashcardId: id,
      noteId: map['noteId'] ?? '',
      frontText: map['frontText'] ?? '',
      backText: map['backText'] ?? '',
      generatedAt: map['generatedAt'] is Timestamp
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'noteId': noteId,
        'frontText': frontText,
        'backText': backText,
        'generatedAt': generatedAt,
      };
}
