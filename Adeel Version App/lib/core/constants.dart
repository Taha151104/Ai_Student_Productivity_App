/// App-wide constants: collection names, API endpoints, and shared strings.
/// Keep this file as the single source of truth so Firestore collection
/// names stay consistent with the ERD.
class AppConstants {
  AppConstants._();

  // ── Top-level Firestore collections ──────────────────────────────────────
  static const String usersCollection = 'users';
  static const String notesCollection = 'notes';
  static const String summariesCollection = 'summaries';
  static const String quizzesCollection = 'quizzes';
  static const String flashcardsCollection = 'flashcards';
  static const String ocrDocumentsCollection = 'ocr_documents';
  static const String chatSessionsCollection = 'ai_chat_sessions';
  static const String progressCollection = 'progress';
  static const String remindersCollection = 'reminders';
  static const String supportTicketsCollection = 'support_tickets';

  // ── Subcollections ────────────────────────────────────────────────────────
  /// Learner-memory facts stored under users/{uid}/memories/{factKey}.
  /// Each document: { key, value, updatedAt }
  static const String memoriesSubcollection = 'memories';

  // ── AI API ────────────────────────────────────────────────────────────────
  static const String huggingFaceApiBaseUrl =
      'https://router.huggingface.co/v1/chat/completions';

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const String appName = 'AI Student Productivity Ecosystem';
}
