import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// Generic Firestore CRUD wrapper.
/// Feature services call through here instead of importing cloud_firestore
/// directly, so collection-name typos and query logic stay in one place.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Top-level document helpers ────────────────────────────────────────────

  Future<DocumentReference> addDocument(
      String collection, Map<String, dynamic> data) {
    return _db.collection(collection).add(data);
  }

  Future<void> setDocument(
      String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).set(data);
  }

  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).delete();
  }

  Stream<QuerySnapshot> streamCollection(String collection,
      {String? whereUserId}) {
    final ref = _db.collection(collection);
    if (whereUserId != null) {
      return ref.where('userId', isEqualTo: whereUserId).snapshots();
    }
    return ref.snapshots();
  }

  // ── Subcollection helpers ─────────────────────────────────────────────────

  /// Returns a reference to a subcollection under a parent document.
  CollectionReference subcollection(
          String parentCollection, String parentId, String sub) =>
      _db.collection(parentCollection).doc(parentId).collection(sub);

  /// Reads all documents from a subcollection.
  Future<List<QueryDocumentSnapshot>> getSubcollection(
      String parentCollection, String parentId, String sub) async {
    final snap = await subcollection(parentCollection, parentId, sub).get();
    return snap.docs;
  }

  // ── Learner-memory helpers ────────────────────────────────────────────────

  /// Upserts a single memory fact for a user.
  /// Uses the [key] as the document ID so each fact is stored once and
  /// overwritten if a newer value is extracted (no duplicates).
  ///
  /// Document shape: { key, value, updatedAt }
  Future<void> upsertMemory(String userId, String key, String value) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.memoriesSubcollection)
        .doc(key) // key IS the document ID
        .set({
      'key': key,
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // non-destructive — only updates these fields
  }

  /// Loads all memory facts for a user as a plain map {key: value}.
  Future<Map<String, String>> loadMemories(String userId) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.memoriesSubcollection)
        .get();

    return {
      for (final doc in snap.docs)
        (doc.data()['key'] as String? ?? doc.id):
            (doc.data()['value'] as String? ?? ''),
    };
  }

  /// Deletes a single memory fact.
  Future<void> deleteMemory(String userId, String key) => _db
      .collection(AppConstants.usersCollection)
      .doc(userId)
      .collection(AppConstants.memoriesSubcollection)
      .doc(key)
      .delete();

  // ── Convenience shortcuts ─────────────────────────────────────────────────

  Future<DocumentReference> saveNote(Map<String, dynamic> note) =>
      addDocument(AppConstants.notesCollection, note);
  Future<DocumentReference> saveSummary(Map<String, dynamic> summary) =>
      addDocument(AppConstants.summariesCollection, summary);
  Future<DocumentReference> saveOcrDocument(Map<String, dynamic> doc) =>
      addDocument(AppConstants.ocrDocumentsCollection, doc);
}
