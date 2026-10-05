import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/ai_service.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final _controller = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isAdding = false;

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFF3F0FF);
  static const Color fieldFill = Colors.white;
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF6E6B82);

  static const int maxFolders = 8;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addSubject(int currentCount) async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    if (currentCount >= maxFolders) {
      _snack(
          'Folder limit reached ($maxFolders max). Delete one to add a new subject.',
          Colors.orange);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _snack('You must be logged in.', Colors.red);
      return;
    }

    setState(() => _isAdding = true);
    try {
      _controller.clear();
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subjects')
          .add({
        'userId': user.uid,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('📁 Subject "$name" created in your cloud!', Colors.green);
    } catch (e) {
      _snack('Failed to create folder: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteSubject(String docId, String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
            'All syllabus notes and files inside this subject folder will be removed from your cloud.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final subjectRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subjects')
          .doc(docId);
      final filesSnap = await subjectRef.collection('files').get();
      for (final doc in filesSnap.docs) {
        final chunksSnap = await doc.reference.collection('chunks').get();
        for (final c in chunksSnap.docs) {
          await c.reference.delete();
        }
        await doc.reference.delete();
      }
      await subjectRef.delete();
      _snack('Subject removed from your cloud.', Colors.blueGrey);
    } catch (e) {
      _snack('Could not delete: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'My Subjects (Syllabus Hub)',
          style: TextStyle(
              color: textDark, fontWeight: FontWeight.w800, fontSize: 19),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please log in to manage your subjects.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('subjects')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final folderCount = docs.length;

                return Column(
                  children: [
                    // Creation bar & limit indicator
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Semester Subjects',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textMuted),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: folderCount >= maxFolders
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$folderCount / $maxFolders Folders',
                                  style: TextStyle(
                                    color: folderCount >= maxFolders
                                        ? Colors.deepOrange
                                        : primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  enabled:
                                      folderCount < maxFolders && !_isAdding,
                                  style: const TextStyle(
                                      color: textDark, fontSize: 14.5),
                                  decoration: InputDecoration(
                                    hintText: folderCount >= maxFolders
                                        ? 'Maximum 8 folders reached'
                                        : 'e.g. CS101, Data Structures...',
                                    hintStyle: const TextStyle(
                                        color: textMuted, fontSize: 13.5),
                                    filled: true,
                                    fillColor: fieldFill,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                          color:
                                              primary.withValues(alpha: 0.15)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: primary, width: 2),
                                    ),
                                  ),
                                  onSubmitted: (_) => _addSubject(folderCount),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed:
                                    (folderCount >= maxFolders || _isAdding)
                                        ? null
                                        : () => _addSubject(folderCount),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isAdding
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Add',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Subject folder list
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(
                              child: CircularProgressIndicator(color: primary))
                          : docs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.folder_copy_outlined,
                                          size: 64,
                                          color:
                                              primary.withValues(alpha: 0.3)),
                                      const SizedBox(height: 12),
                                      const Text(
                                          'No subject folders created yet.',
                                          style: TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'Create folders (up to 8) to upload course books (PDF, PNG, JPG)\nso you can open them anytime & ground AI Chat.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: textMuted, fontSize: 12)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(18),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final doc = docs[i];
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        data['name'] ?? 'Unnamed Subject';

                                    return InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SubjectDetailScreen(
                                              userId: user.uid,
                                              subjectId: doc.id,
                                              subjectName: name,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                                color: primary.withValues(
                                                    alpha: 0.06),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4)),
                                          ],
                                          border: Border.all(
                                              color: primary.withValues(
                                                  alpha: 0.1)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                    colors: [
                                                      Color(0xFF6366F1),
                                                      Color(0xFF38BDF8)
                                                    ]),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                  Icons.folder_rounded,
                                                  color: Colors.white,
                                                  size: 26),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                        color: textDark),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: _firestore
                                                        .collection('users')
                                                        .doc(user.uid)
                                                        .collection('subjects')
                                                        .doc(doc.id)
                                                        .collection('files')
                                                        .snapshots(),
                                                    builder: (ctx, fileSnap) {
                                                      final count = fileSnap
                                                              .data
                                                              ?.docs
                                                              .length ??
                                                          0;
                                                      return Text(
                                                        '$count file${count == 1 ? '' : 's'} saved in cloud',
                                                        style: const TextStyle(
                                                            color: textMuted,
                                                            fontSize: 12),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.redAccent,
                                                  size: 20),
                                              onPressed: () =>
                                                  _deleteSubject(doc.id, name),
                                            ),
                                            const Icon(
                                                Icons.chevron_right_rounded,
                                                color: textMuted),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Detail Screen: Upload, Open & View PDFs, Images, and Notes
// ─────────────────────────────────────────────────────────────────────────────

class SubjectDetailScreen extends StatefulWidget {
  final String userId;
  final String subjectId;
  final String subjectName;

  const SubjectDetailScreen({
    super.key,
    required this.userId,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _aiService = AiService();
  bool _isUploading = false;
  String _uploadStatus = '';

  // In-memory cache for fast instant opening during the current session
  static final Map<String, Uint8List> _memoryFileCache = {};

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFF3F0FF);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF6E6B82);

  // ── 1. Pick and OCR Image (Camera / Gallery) ──────────────────────────────
  Future<void> _pickAndOcrImage(ImageSource source) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Selecting image...';
    });

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 82,
      );
      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }

      final Uint8List imageBytes = await image.readAsBytes();
      final filename = image.name.isNotEmpty
          ? image.name
          : 'Note_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ext = filename.split('.').last.toLowerCase();

      setState(() => _uploadStatus = 'Extracting text from image...');
      String extractedText = '';

      // Try ML Kit on mobile first, fallback to AI Vision OCR on Web/Desktop
      if (!kIsWeb) {
        try {
          final inputImage = InputImage.fromFilePath(image.path);
          final textRecognizer =
              TextRecognizer(script: TextRecognitionScript.latin);
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          await textRecognizer.close();
          extractedText = recognizedText.text.trim();
        } catch (_) {}
      }

      if (extractedText.isEmpty) {
        try {
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          extractedText = await _aiService.extractTextFromImageBytes(
            imageBytes,
            mimeType: mime,
          );
        } catch (_) {
          extractedText = 'Image note: $filename';
        }
      }

      setState(() => _uploadStatus = 'Saving file to your cloud folder...');
      await _saveFileToFirestore(
        fileName: filename,
        fileType: ext,
        fileBytes: imageBytes,
        extractedContent: extractedText,
      );

      _snack('✅ "$filename" saved! Tap on it anytime to open.', Colors.green);
    } catch (e) {
      _snack('Failed to upload image: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── 2. Pick Document / PDF (.pdf, .txt, .png, .jpg) ───────────────────────
  Future<void> _pickDocumentFile() async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Opening file picker...';
    });

    try {
      const typeGroup = XTypeGroup(
        label: 'PDF & Study Files',
        extensions: ['pdf', 'txt', 'md', 'png', 'jpg', 'jpeg'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      final ext = file.name.split('.').last.toLowerCase();
      setState(() => _uploadStatus = 'Reading ${file.name}...');

      final Uint8List bytes = await file.readAsBytes();
      String extractedText = '';

      if (ext == 'txt' || ext == 'md') {
        extractedText = utf8.decode(bytes, allowMalformed: true).trim();
      } else if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
        try {
          extractedText = await _aiService.extractTextFromImageBytes(
            bytes,
            mimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
          );
        } catch (_) {}
      } else if (ext == 'pdf') {
        setState(() => _uploadStatus = 'Extracting text from PDF pages...');
        extractedText = await _extractReadablePdfText(bytes, file.name);
      }

      if (extractedText.trim().isEmpty) {
        extractedText = 'Study document: ${file.name}';
      }

      setState(() => _uploadStatus = 'Saving PDF to cloud folder...');
      await _saveFileToFirestore(
        fileName: file.name,
        fileType: ext,
        fileBytes: bytes,
        extractedContent: extractedText,
      );

      _snack('✅ "${file.name}" saved! Tap on it to open PDF.', Colors.green);
    } catch (e) {
      _snack('Failed to import file: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Extracts readable text from PDF pages for AI Chat grounding & preview
  Future<String> _extractReadablePdfText(
      Uint8List pdfBytes, String fileName) async {
    final StringBuffer buffer = StringBuffer();

    // 1. Try rasterizing first 2 pages for OCR text extraction
    try {
      int pageIndex = 0;
      await for (final page in Printing.raster(pdfBytes, dpi: 120)) {
        final pngBytes = await page.toPng();
        final pageText = await _aiService.extractTextFromImageBytes(
          pngBytes,
          mimeType: 'image/png',
        );
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText.trim());
        }
        pageIndex++;
        if (pageIndex >= 2) break;
      }
    } catch (_) {}

    if (buffer.toString().trim().length > 30) {
      return buffer.toString().trim();
    }

    // 2. Fallback: Extract literal text strings inside PDF BT..ET blocks
    try {
      final rawLatin = latin1.decode(pdfBytes, allowInvalid: true);
      final btEtRegex = RegExp(r'BT[\s\S]*?ET');
      final literalRegex = RegExp(r'\(([^()\\]*(?:\\.[^()\\]*)*)\)');
      final parts = <String>[];

      for (final block in btEtRegex.allMatches(rawLatin)) {
        final textBlock = block.group(0) ?? '';
        for (final m in literalRegex.allMatches(textBlock)) {
          final s = (m.group(1) ?? '').trim();
          if (s.isNotEmpty &&
              !s.startsWith('%PDF') &&
              !s.contains('/Filter') &&
              !s.contains('/Type')) {
            parts.add(s);
          }
        }
      }
      final joined = parts.join(' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (joined.length > 30) return joined;
    } catch (_) {}

    return 'PDF Document: $fileName (Tap to view full PDF pages)';
  }

  /// Saves file metadata, extracted text, and binary bytes (inline or chunked) to Firestore
  Future<void> _saveFileToFirestore({
    required String fileName,
    required String fileType,
    required Uint8List fileBytes,
    required String extractedContent,
  }) async {
    final String base64Full = base64Encode(fileBytes);
    // Keep each Firestore document well under the 1MB limit (~500KB per chunk)
    const int chunkSize = 500000;
    final bool fitsInline = base64Full.length <= chunkSize;

    final filesCol = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('subjects')
        .doc(widget.subjectId)
        .collection('files');

    final previewText = extractedContent.length > 120
        ? '${extractedContent.substring(0, 120)}...'
        : extractedContent;

    final docRef = await filesCol.add({
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileBytes.length,
      'extractedContent': extractedContent.length > 20000
          ? extractedContent.substring(0, 20000)
          : extractedContent,
      'preview': previewText,
      'isChunked': !fitsInline,
      'chunkCount': fitsInline ? 0 : (base64Full.length / chunkSize).ceil(),
      if (fitsInline) 'base64Data': base64Full,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    // Cache bytes in memory for instant opening
    _memoryFileCache[docRef.id] = fileBytes;

    // If file is larger than 500KB, store binary chunks in subcollection
    if (!fitsInline && base64Full.length <= chunkSize * 16) {
      int index = 0;
      for (int offset = 0; offset < base64Full.length; offset += chunkSize) {
        final end = (offset + chunkSize < base64Full.length)
            ? offset + chunkSize
            : base64Full.length;
        await docRef.collection('chunks').doc('$index').set({
          'index': index,
          'data': base64Full.substring(offset, end),
        });
        index++;
      }
    }
  }

  /// Opens the tapped PDF, Image, or Text file in SubjectFileViewerScreen
  void _openSavedFile(String fileId, Map<String, dynamic> fileData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectFileViewerScreen(
          userId: widget.userId,
          subjectId: widget.subjectId,
          fileId: fileId,
          fileData: fileData,
          cachedBytes: _memoryFileCache[fileId],
        ),
      ),
    );
  }

  Future<void> _deleteFile(String fileId) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('files')
          .doc(fileId);

      final chunks = await docRef.collection('chunks').get();
      for (final c in chunks.docs) {
        await c.reference.delete();
      }
      await docRef.delete();
      _memoryFileCache.remove(fileId);

      _snack('File removed from your cloud account.', Colors.blueGrey);
    } catch (e) {
      _snack('Could not delete file: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required bool isPrimary,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isPrimary ? primary : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? primary : color.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isPrimary ? Colors.white : color,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          children: [
            Text(widget.subjectName,
                style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const Text('Tap any saved PDF or file below to open it',
                style: TextStyle(
                    color: primary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Upload Banner
          Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primary.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                    color: primary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Upload Course Books & Notes',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accepted: PDF, PNG, JPG, TXT. Tap any uploaded file below to view & read.',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: primary)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _uploadStatus,
                            style: const TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      _buildActionButton(
                        onTap: () => _pickAndOcrImage(ImageSource.camera),
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: primary,
                        isPrimary: false,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        onTap: () => _pickAndOcrImage(ImageSource.gallery),
                        icon: Icons.image_rounded,
                        label: 'Gallery',
                        color: const Color(0xFF0284C7),
                        isPrimary: false,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        onTap: _pickDocumentFile,
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF / Docs',
                        color: primary,
                        isPrimary: true,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // File List Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.userId)
                  .collection('subjects')
                  .doc(widget.subjectId)
                  .collection('files')
                  .orderBy('uploadedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primary));
                }

                final files = snapshot.data?.docs ?? [];
                if (files.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 54, color: primary.withValues(alpha: 0.35)),
                          const SizedBox(height: 12),
                          const Text('No files in this subject yet.',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textDark)),
                          const SizedBox(height: 6),
                          const Text(
                              'Upload PDFs or pictures of your lecture notes.\nTap any saved file to open and read it inside the app.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: textMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = files[i];
                    final f = doc.data() as Map<String, dynamic>;
                    final name = f['fileName'] ?? 'Note File';
                    final preview = f['preview'] ?? '';
                    final type =
                        (f['fileType'] ?? 'file').toString().toLowerCase();

                    IconData iconData = Icons.description_rounded;
                    Color iconColor = primary;
                    if (type == 'pdf') {
                      iconData = Icons.picture_as_pdf_rounded;
                      iconColor = Colors.redAccent;
                    } else if (['png', 'jpg', 'jpeg', 'jfif'].contains(type)) {
                      iconData = Icons.image_rounded;
                      iconColor = const Color(0xFF0284C7);
                    }

                    // ── Clickable Card to Open PDF / Image / Document ──
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _openSavedFile(doc.id, f),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child:
                                    Icon(iconData, color: iconColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: textDark),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: iconColor.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            type.toUpperCase(),
                                            style: TextStyle(
                                                color: iconColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: textMuted,
                                          fontSize: 11.5,
                                          height: 1.3),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.visibility_outlined,
                                            size: 13, color: iconColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Tap to open ${type.toUpperCase()}',
                                          style: TextStyle(
                                            color: iconColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete file',
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteFile(doc.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Built-in PDF, Image & Study Note Viewer Screen
// ─────────────────────────────────────────────────────────────────────────────

class SubjectFileViewerScreen extends StatefulWidget {
  final String userId;
  final String subjectId;
  final String fileId;
  final Map<String, dynamic> fileData;
  final Uint8List? cachedBytes;

  const SubjectFileViewerScreen({
    super.key,
    required this.userId,
    required this.subjectId,
    required this.fileId,
    required this.fileData,
    this.cachedBytes,
  });

  @override
  State<SubjectFileViewerScreen> createState() =>
      _SubjectFileViewerScreenState();
}

class _SubjectFileViewerScreenState extends State<SubjectFileViewerScreen> {
  Uint8List? _fileBytes;
  bool _isLoading = true;
  int _selectedViewTab = 0; // 0 = Document/PDF View, 1 = Extracted Text View

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFF3F0FF);
  static const Color textDark = Color(0xFF1A1040);

  @override
  void initState() {
    super.initState();
    _loadFileBytes();
  }

  Future<void> _loadFileBytes() async {
    // 1. Check in-memory cache first
    if (widget.cachedBytes != null) {
      if (mounted) {
        setState(() {
          _fileBytes = widget.cachedBytes;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Check inline base64Data in document
    final inlineBase64 = widget.fileData['base64Data'] as String?;
    if (inlineBase64 != null && inlineBase64.isNotEmpty) {
      try {
        final decoded = base64Decode(inlineBase64);
        if (mounted) {
          setState(() {
            _fileBytes = decoded;
            _isLoading = false;
          });
        }
        return;
      } catch (_) {}
    }

    // 3. Check chunked binary data in Firestore subcollection
    if (widget.fileData['isChunked'] == true) {
      try {
        final chunksSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('subjects')
            .doc(widget.subjectId)
            .collection('files')
            .doc(widget.fileId)
            .collection('chunks')
            .orderBy('index')
            .get();

        if (chunksSnap.docs.isNotEmpty) {
          final buffer = StringBuffer();
          for (final doc in chunksSnap.docs) {
            buffer.write(doc.data()['data'] ?? '');
          }
          final decoded = base64Decode(buffer.toString());
          if (mounted) {
            setState(() {
              _fileBytes = decoded;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Error loading PDF chunks: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Generates a clean printable PDF if the file only has extracted text (e.g., older files or .txt)
  Future<Uint8List> _buildPdfBytes(PdfPageFormat format) async {
    final type = (widget.fileData['fileType'] ?? '').toString().toLowerCase();

    // If original PDF bytes exist and start with %PDF, return the exact original PDF!
    if (_fileBytes != null &&
        type == 'pdf' &&
        _fileBytes!.length > 4 &&
        _fileBytes![0] == 0x25 && // '%'
        _fileBytes![1] == 0x50 && // 'P'
        _fileBytes![2] == 0x44 && // 'D'
        _fileBytes![3] == 0x46) {
      return _fileBytes!;
    }

    // Otherwise generate a clean study PDF from extractedContent or image
    final pdf = pw.Document();
    final title = (widget.fileData['fileName'] ?? 'Study Document').toString();
    final content = (widget.fileData['extractedContent'] ?? '').toString();

    if (_fileBytes != null &&
        ['png', 'jpg', 'jpeg', 'jfif'].contains(type)) {
      final image = pw.MemoryImage(_fileBytes!);
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Expanded(child: pw.Center(child: pw.Image(image))),
            ],
          ),
        ),
      );
      return pdf.save();
    }

    // Split text into clean paragraphs for MultiPage PDF rendering
    final paragraphs = content
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          if (paragraphs.isEmpty)
            pw.Text('No text content available.')
          else
            ...paragraphs.map(
              (p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(p, style: const pw.TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final fileName =
        (widget.fileData['fileName'] ?? 'Study Document').toString();
    final fileType =
        (widget.fileData['fileType'] ?? 'pdf').toString().toLowerCase();
    final extractedContent =
        (widget.fileData['extractedContent'] ?? '').toString();
    final isImage = ['png', 'jpg', 'jpeg', 'jfif'].contains(fileType);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          fileName,
          style: const TextStyle(
              color: textDark, fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Toggle between PDF/Image View and Extracted Text View
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedViewTab = _selectedViewTab == 0 ? 1 : 0;
                });
              },
              icon: Icon(
                _selectedViewTab == 0
                    ? Icons.subject_rounded
                    : Icons.picture_as_pdf_rounded,
                color: primary,
                size: 18,
              ),
              label: Text(
                _selectedViewTab == 0 ? 'Read Text' : 'PDF View',
                style: const TextStyle(
                    color: primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primary),
                  SizedBox(height: 12),
                  Text('Opening document from cloud...'),
                ],
              ),
            )
          : _selectedViewTab == 1
              // ── Tab 1: Selectable Extracted Text View ──
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.15)),
                    ),
                    child: SelectableText(
                      extractedContent.isNotEmpty
                          ? extractedContent
                          : 'No extracted text available for this file.',
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                )
              // ── Tab 0: Interactive Image or PDF Viewer ──
              : (isImage && _fileBytes != null)
                  ? Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_fileBytes!),
                          ),
                        ),
                      ),
                    )
                  : PdfPreview(
                      build: (format) => _buildPdfBytes(format),
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      pdfFileName:
                          fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
                      loadingWidget: const Center(
                        child: CircularProgressIndicator(color: primary),
                      ),
                    ),
    );
  }
}