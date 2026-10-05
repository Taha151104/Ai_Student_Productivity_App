import 'package:cloud_firestore/cloud_firestore.dart';

class SummaryModel {
  final String summaryId;
  final String noteId;
  final String summaryText;
  final String format; // 'short' or 'detailed'
  final DateTime generatedAt;

  SummaryModel({
    required this.summaryId,
    required this.noteId,
    required this.summaryText,
    required this.format,
    required this.generatedAt,
  });

  factory SummaryModel.fromMap(String id, Map<String, dynamic> map) {
    return SummaryModel(
      summaryId: id,
      noteId: map['noteId'] ?? '',
      summaryText: map['summaryText'] ?? '',
      format: map['format'] ?? 'short',
      generatedAt: map['generatedAt'] is Timestamp
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'noteId': noteId,
        'summaryText': summaryText,
        'format': format,
        'generatedAt': generatedAt,
      };
}
