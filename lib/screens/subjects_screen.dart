import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Provides kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
        Colors.orange,
      );
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
          'All syllabus notes and files inside this subject folder will be removed from your cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
            color: textDark,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
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
                                  color: textMuted,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: folderCount >= maxFolders
                                      ? Colors.orange.withOpacity(0.15)
                                      : primary.withOpacity(0.12),
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
                                    color: textDark,
                                    fontSize: 14.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: folderCount >= maxFolders
                                        ? 'Maximum 8 folders reached'
                                        : 'e.g. CS101, Data Structures...',
                                    hintStyle: const TextStyle(
                                      color: textMuted,
                                      fontSize: 13.5,
                                    ),
                                    filled: true,
                                    fillColor: fieldFill,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: primary.withOpacity(0.15),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: primary,
                                        width: 2,
                                      ),
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
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isAdding
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Add',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                              child: CircularProgressIndicator(color: primary),
                            )
                          : docs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.folder_copy_outlined,
                                        size: 64,
                                        color: primary.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No subject folders created yet.',
                                        style: TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Create folders (up to 8) to upload course books (PDF, PNG, JPG)\nso AI Chat can ground answers in your syllabus.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
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
                                              color: primary.withOpacity(0.06),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: primary.withOpacity(0.1),
                                          ),
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
                                                    Color(0xFF38BDF8),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.folder_rounded,
                                                color: Colors.white,
                                                size: 26,
                                              ),
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
                                                      color: textDark,
                                                    ),
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
                                                          fontSize: 12,
                                                        ),
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
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _deleteSubject(doc.id, name),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: textMuted,
                                            ),
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
// Subject Detail Screen: Web-Safe Cloud Storage for PDF, PNG, JPG, JPEG, JFIF
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
  bool _isUploading = false;
  String _uploadStatus = '';

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFF3F0FF);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF6E6B82);

  // 1. Pick and OCR Image (Handles both Native Android & Web Browser smoothly)
  Future<void> _pickAndOcrImage(ImageSource source) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Selecting image...';
    });

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) {
        setState(() => _isUploading = false);
        return;
      }

      final filename = image.name.isNotEmpty
          ? image.name
          : 'Image_${DateTime.now().millisecondsSinceEpoch}.png';

      String extractedText = '';

      if (kIsWeb) {
        // On Web browser: ML Kit is mobile-only, so we read image metadata/bytes
        setState(() => _uploadStatus = 'Uploading image to syllabus cloud...');
        extractedText =
            'Image lecture note ($filename) uploaded for ${widget.subjectName}. Full on-device ML Kit OCR runs on Android/iOS native mobile devices.';
      } else {
        // On Native Android / iOS Devices: Run Google ML Kit OCR
        setState(
          () => _uploadStatus = 'Extracting textbook text via ML Kit OCR...',
        );
        try {
          final inputImage = InputImage.fromFilePath(image.path);
          final textRecognizer =
              TextRecognizer(script: TextRecognitionScript.latin);
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          await textRecognizer.close();
          extractedText = recognizedText.text.trim();
        } catch (ocrErr) {
          debugPrint('ML Kit Native OCR Fallback: $ocrErr');
          extractedText =
              'Lecture note ($filename) uploaded for ${widget.subjectName}.';
        }
      }

      if (extractedText.isEmpty) {
        extractedText = 'Lecture document: $filename';
      }

      setState(() => _uploadStatus = 'Saving to your Firebase cloud...');
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('files')
          .add({
        'fileName': filename,
        'fileType': filename.split('.').last.toLowerCase(),
        'extractedContent': extractedText,
        'preview': extractedText.length > 120
            ? '${extractedText.substring(0, 120)}...'
            : extractedText,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      _snack(
        kIsWeb
            ? '✅ "$filename" saved in cloud! (Native ML Kit OCR activates on phone)'
            : '✅ "$filename" saved in cloud & linked to AI Chat!',
        Colors.green,
      );
    } catch (e) {
      _snack('Upload failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 2. Pick Document / PDF (supports .pdf, .txt, .png, .jpg, .jfif, .doc)
  Future<void> _pickDocumentFile() async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Opening document picker...';
    });

    try {
      const typeGroup = XTypeGroup(
        label: 'PDF & Documents',
        mimeTypes: ['application/pdf', 'text/plain'],
        extensions: ['pdf', 'txt', 'doc', 'docx'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      final ext = file.name.split('.').last.toLowerCase();
      setState(() => _uploadStatus = 'Reading $ext content...');

      final Uint8List bytes = await file.readAsBytes();
      String extractedText = '';
      try {
        extractedText = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        extractedText = String.fromCharCodes(bytes);
      }

      final cleanContent = extractedText
          .replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      final finalContent = cleanContent.length > 50
          ? cleanContent
          : 'Syllabus reference: ${file.name}. Please prioritize university curriculum questions based on this document.';

      setState(() => _uploadStatus = 'Uploading to cloud account...');
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('files')
          .add({
        'fileName': file.name,
        'fileType': ext,
        'extractedContent': finalContent,
        'preview': finalContent.length > 120
            ? '${finalContent.substring(0, 120)}...'
            : finalContent,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      _snack('✅ "${file.name}" uploaded to cloud!', Colors.green);
    } catch (e) {
      _snack('Failed to import file: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteFile(String fileId) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('subjects')
          .doc(widget.subjectId)
          .collection('files')
          .doc(fileId)
          .delete();
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
            color: isPrimary ? primary : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? primary : color.withOpacity(0.35),
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
            Text(
              widget.subjectName,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const Text(
              'Cloud Syllabus Knowledge Base',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Action Banner with clean, un-crowded buttons
          Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
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
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Accepted: PDF, PNG, JPG, JPEG, JFIF, TXT. Files are read by AI Chat.',
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
                            strokeWidth: 2,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _uploadStatus,
                          style: const TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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

          // File List Stream from User's Cloud
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
                    child: CircularProgressIndicator(color: primary),
                  );
                }

                final files = snapshot.data?.docs ?? [];
                if (files.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 54,
                            color: primary.withOpacity(0.35),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No files in this subject yet.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Upload PDFs or pictures of your lecture notes.\nThey will sync to your cloud and ground your AI Chat answers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12.5,
                            ),
                          ),
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
                    final f = files[i].data() as Map<String, dynamic>;
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

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primary.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconData, color: iconColor, size: 22),
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
                                          color: textDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: iconColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: TextStyle(
                                          color: iconColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
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
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => _deleteFile(files[i].id),
                          ),
                        ],
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
