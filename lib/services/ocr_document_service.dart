import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the OCR_DOCUMENT entity from the ERD:
///   DocumentID (PK), UserID (FK), FilePath, Date_Uploaded
///
/// [extractedText] is stored here too (not a separate ERD entity) since
/// it's the OCR output tied directly to this document, and it's what
/// gets sent to the AI API for Summary/Quiz/Chat/Flashcard generation.
class OcrDocument {
  final String documentId;
  final String userId;
  final String filePath;
  final String extractedText;
  final DateTime dateUploaded;

  OcrDocument({
    required this.documentId,
    required this.userId,
    required this.filePath,
    required this.extractedText,
    required this.dateUploaded,
  });

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'userId': userId,
      'filePath': filePath,
      'extractedText': extractedText,
      'dateUploaded': Timestamp.fromDate(dateUploaded),
    };
  }

  factory OcrDocument.fromMap(Map<String, dynamic> map) {
    return OcrDocument(
      documentId: map['documentId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      filePath: map['filePath'] as String? ?? '',
      extractedText: map['extractedText'] as String? ?? '',
      // Firestore always returns a Timestamp, never a Dart DateTime
      // directly. Guard both cases anyway — this is the recurring
      // bug pattern across every model in this project.
      dateUploaded: _parseDate(map['dateUploaded']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  /// Returns a copy of this document with the given fields replaced.
  OcrDocument copyWith({
    String? filePath,
    String? extractedText,
  }) {
    return OcrDocument(
      documentId: documentId,
      userId: userId,
      filePath: filePath ?? this.filePath,
      extractedText: extractedText ?? this.extractedText,
      dateUploaded: dateUploaded,
    );
  }
}

/// Handles all Firestore reads/writes for OCR_DOCUMENT records.
///
/// Uses a flat top-level collection ('ocr_documents') with a userId
/// field acting as the FK, matching the relational structure in the
/// ERD/Design Document rather than nested subcollections — keeps the
/// Firestore schema a direct match to the approved 10-entity ERD.
class OcrDocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('ocr_documents');

  /// Generates a new Firestore-backed document ID. Call this FIRST,
  /// before saving the physical file, so the same ID can be used for
  /// both LocalFileService.saveNoteFile() and this record — keeping
  /// the file and its Firestore metadata in sync.
  String generateDocumentId() {
    return _collection.doc().id;
  }

  /// Saves (creates or overwrites) an OCR_DOCUMENT record.
  Future<void> saveDocument(OcrDocument document) async {
    await _collection.doc(document.documentId).set(document.toMap());
  }

  /// Updates just the filePath and/or extractedText on an existing
  /// record, without needing to re-supply every field.
  Future<void> updateDocument({
    required String documentId,
    String? filePath,
    String? extractedText,
  }) async {
    final updates = <String, dynamic>{};
    if (filePath != null) updates['filePath'] = filePath;
    if (extractedText != null) updates['extractedText'] = extractedText;
    if (updates.isEmpty) return;

    await _collection.doc(documentId).update(updates);
  }

  /// Fetches a single OCR_DOCUMENT by ID.
  Future<OcrDocument?> getDocument(String documentId) async {
    final snapshot = await _collection.doc(documentId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return OcrDocument.fromMap(snapshot.data()!);
  }

  /// Fetches all OCR_DOCUMENT records for a user, most recent first.
  /// Call this on login / app start to repopulate the user's Notes
  /// list from Firestore.
  Future<List<OcrDocument>> getAllDocumentsForUser(String userId) async {
    final snapshot = await _collection
        .where('userId', isEqualTo: userId)
        .orderBy('dateUploaded', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => OcrDocument.fromMap(doc.data()))
        .toList();
  }

  /// Live stream version of [getAllDocumentsForUser], if you want the
  /// Notes list to update in real time as documents are added/removed
  /// (e.g. across multiple devices signed into the same account).
  Stream<List<OcrDocument>> watchDocumentsForUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('dateUploaded', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OcrDocument.fromMap(doc.data())).toList());
  }

  /// Deletes the Firestore record. Remember to also call
  /// LocalFileService.deleteNoteFile() with the same filePath so you
  /// don't leave an orphaned file on the device.
  Future<void> deleteDocument(String documentId) async {
    await _collection.doc(documentId).delete();
  }
}
