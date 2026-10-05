import 'package:cloud_firestore/cloud_firestore.dart';

class OcrDocumentModel {
  final String ocrDocumentId;
  final String userId;
  final String imagePath;
  final String extractedText;
  final DateTime processedAt;

  OcrDocumentModel({
    required this.ocrDocumentId,
    required this.userId,
    required this.imagePath,
    required this.extractedText,
    required this.processedAt,
  });

  factory OcrDocumentModel.fromMap(String id, Map<String, dynamic> map) {
    return OcrDocumentModel(
      ocrDocumentId: id,
      userId: map['userId'] ?? '',
      imagePath: map['imagePath'] ?? '',
      extractedText: map['extractedText'] ?? '',
      processedAt: map['processedAt'] is Timestamp
          ? (map['processedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'imagePath': imagePath,
        'extractedText': extractedText,
        'processedAt': processedAt,
      };
}
