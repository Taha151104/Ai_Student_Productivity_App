import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Handles saving, retrieving, and deleting locally-stored note files
/// (scanned images / uploaded PDFs) in the app's private sandboxed storage.
///
/// This class does NOT touch Firestore — it only manages the physical
/// file on the device. Pair it with [OcrDocumentService] (see
/// ocr_document_service.dart) to persist the resulting file path and
/// metadata to the user's account, so their notes list can be rebuilt
/// on login.
///
/// Files are stored at:
///   <appDocumentsDirectory>/notes/<userId>/<documentId>.<extension>
///
/// This location is private to the app on both Android and iOS, so no
/// storage permission is required.
class LocalFileService {
  static const String _notesFolderName = 'notes';

  /// Returns (and creates if needed) the app's private notes directory
  /// for a specific user.
  Future<Directory> _getUserNotesDirectory(String userId) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final userDir = Directory('${appDocDir.path}/$_notesFolderName/$userId');

    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    return userDir;
  }

  /// Copies a picked/captured file (e.g. from image_picker or
  /// file_picker) into the app's private storage and returns the new
  /// local path.
  ///
  /// - [sourceFile] is the temporary file returned by the picker.
  /// - [userId] is the currently logged-in user's UID.
  /// - [documentId] should be the SAME id you use for the OCR_DOCUMENT
  ///   Firestore record, so the physical file and its metadata always
  ///   stay in sync and are easy to reconcile.
  Future<String> saveNoteFile({
    required File sourceFile,
    required String userId,
    required String documentId,
  }) async {
    final userDir = await _getUserNotesDirectory(userId);
    final extension = sourceFile.path.contains('.')
        ? sourceFile.path.split('.').last
        : 'jpg';
    final destinationPath = '${userDir.path}/$documentId.$extension';

    final savedFile = await sourceFile.copy(destinationPath);
    return savedFile.path;
  }

  /// Returns true if the file at [filePath] still exists on this device.
  ///
  /// Always check this before rendering an image widget from a stored
  /// path. The file will be missing if the user logged in on a
  /// different device than the one they originally scanned the note
  /// on — in that case, fall back to showing the extracted text
  /// instead of the image.
  Future<bool> fileExists(String filePath) async {
    if (filePath.isEmpty) return false;
    return File(filePath).exists();
  }

  /// Returns the file, or null if it doesn't exist locally.
  Future<File?> getNoteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) return file;
    return null;
  }

  /// Deletes the local file, if present. Call this whenever the user
  /// deletes a note, so you don't leave orphaned files taking up
  /// device storage.
  Future<void> deleteNoteFile(String filePath) async {
    if (filePath.isEmpty) return;
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes every locally stored note file for a user. Useful for a
  /// "clear local storage" option in Settings, or when a user deletes
  /// their account.
  Future<void> deleteAllNoteFilesForUser(String userId) async {
    final userDir = await _getUserNotesDirectory(userId);
    if (await userDir.exists()) {
      await userDir.delete(recursive: true);
    }
  }

  /// Total size (in bytes) of all locally stored notes for a user.
  /// Handy if you want to show "local storage used" in Settings.
  Future<int> getUserStorageUsage(String userId) async {
    final userDir = await _getUserNotesDirectory(userId);
    if (!await userDir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in userDir.list()) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes;
  }
}
