import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String noteId;
  final String userId;
  final String title;
  final String content;
  final String? subjectId;
  final DateTime uploadDate;

  NoteModel({
    required this.noteId,
    required this.userId,
    required this.title,
    required this.content,
    this.subjectId,
    required this.uploadDate,
  });

  factory NoteModel.fromMap(String id, Map<String, dynamic> map) {
    return NoteModel(
      noteId: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      subjectId: map['subjectId'],
      uploadDate: map['uploadDate'] is Timestamp
          ? (map['uploadDate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'content': content,
        'subjectId': subjectId,
        'uploadDate': uploadDate,
      };
}
