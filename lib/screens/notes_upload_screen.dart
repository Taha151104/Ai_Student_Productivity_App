import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/ai_service.dart';
import '../services/ocr_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT SCAN & NOTES UPLOAD COLORS RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class NotesUploadTheme {
  static const Color pageBg = Colors.white;
  static const Color electricBlue = Color(0xFF0284C7); // Vibrant Electric Blue
  static const Color skyGlow = Color(0xFF38BDF8); // Bright Cyan / Sky
  static const Color cardFill = Color(0xFFF0F7FF); // Soft Ice Blue Canvas
  static const Color navyDark = Color(0xFF0F172A); // Deep Executive Navy
  static const Color navyAccent = Color(0xFF1E3A8A); // Rich Navy Blue
  static const Color silver = Color(0xFF94A3B8); // Metallic Platinum Silver
  static const Color silverBorder = Color(0xFFCBD5E1); // Crisp Silver Outline
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const List<Color> scanGradient = [
    Color(0xFF38BDF8),
    Color(0xFF0284C7)
  ];
  static const List<Color> saveGradient = [
    Color(0xFF1E3A8A),
    Color(0xFF0F172A)
  ];
}

class NotesUploadScreen extends StatefulWidget {
  const NotesUploadScreen({super.key});

  @override
  State<NotesUploadScreen> createState() => _NotesUploadScreenState();
}

class _NotesUploadScreenState extends State<NotesUploadScreen> {
  final _ocrService = OcrService();
  final _aiService = AiService();
  final _auth = FirebaseAuth.instance;

  Uint8List? _imageBytes;
  File? _imageFile;
  String? _mimeType;
  String? _extractedText;
  bool _isProcessing = false;
  bool _isSavingToSubject = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // ── Image Picking ──────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mime = _mimeFromPath(picked.path);

      setState(() {
        _imageBytes = bytes;
        _imageFile = kIsWeb ? null : File(picked.path);
        _mimeType = mime;
        _extractedText = null;
      });
    } catch (e) {
      _snack('Could not load image: $e', Colors.red);
    }
  }

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'jfif': 'image/jpeg',
      'webp': 'image/webp',
    };
    return map[ext] ?? 'image/jpeg';
  }

  // ── OCR: English + Mathematical Symbols Extraction ─────────────────────────
  Future<void> _runOcr() async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
      _extractedText = null;
    });

    try {
      String text = '';

      if (!kIsWeb && _imageFile != null) {
        // Native mobile ML Kit OCR
        text = await _ocrService.extractTextFromImage(_imageFile!);
      } else {
        // Web / Vision OCR with explicit English & Mathematical Symbol preservation
        text = await _aiService.extractTextFromImageBytes(
          _imageBytes!,
          mimeType: _mimeType ?? 'image/jpeg',
        );
      }

      // Preserve clean mathematical formatting & symbols
      text = _formatMathAndSymbols(text);

      setState(() {
        _extractedText = text.trim().isEmpty
            ? '(No readable text or formulas detected)'
            : text;
      });
    } catch (e) {
      _snack('Extraction failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Ensures mathematical symbols (±, ×, ÷, √, ∑, ∫, π, θ, α, β, etc.) remain intact
  String _formatMathAndSymbols(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\sqrt', '√')
        .replaceAll(r'\sum', '∑')
        .replaceAll(r'\int', '∫')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\theta', 'θ')
        .replaceAll(r'\alpha', 'α')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\Delta', 'Δ');
  }

  // ── Save Extracted Text to an Existing Subject Folder ──────────────────────
  Future<void> _showSaveToSubjectDialog() async {
    final user = _auth.currentUser;
    if (user == null) {
      _snack('Please log in to save to your subjects.', Colors.red);
      return;
    }

    if (_extractedText == null || _extractedText!.trim().isEmpty) {
      _snack('No extracted text to save.', Colors.orange);
      return;
    }

    final subjectsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('subjects')
        .orderBy('createdAt', descending: true)
        .get();

    final docs = subjectsSnap.docs;

    if (docs.isEmpty) {
      _snack(
        'No subject folders exist yet. Create one from the Folders tab first.',
        Colors.orange,
      );
      return;
    }

    String selectedSubjectId = docs.first.id;
    String selectedSubjectName =
        (docs.first.data()['name'] ?? 'Subject Folder').toString();

    final filenameController = TextEditingController(
      text: 'Scan_${DateTime.now().day}_${DateTime.now().month}_Notes.txt',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: const [
                Icon(Icons.folder_shared_rounded,
                    color: NotesUploadTheme.electricBlue),
                SizedBox(width: 8),
                Text(
                  'Save to Subject Folder',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: NotesUploadTheme.textDark,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select an existing subject to store this text file:',
                    style: TextStyle(
                        color: NotesUploadTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // Dropdown of existing folders ONLY (no create folder option)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: NotesUploadTheme.cardFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NotesUploadTheme.silverBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubjectId,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        items: docs.map((d) {
                          final name = d.data()['name'] ?? 'Unnamed Subject';
                          return DropdownMenuItem<String>(
                            value: d.id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.folder_rounded,
                                  color: NotesUploadTheme.electricBlue,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: NotesUploadTheme.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedSubjectId = val;
                              final match = docs.firstWhere((d) => d.id == val);
                              selectedSubjectName = match.data()['name'] ?? '';
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Text File Name:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: NotesUploadTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: filenameController,
                    style: const TextStyle(
                        fontSize: 13.5, color: NotesUploadTheme.textDark),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: NotesUploadTheme.silverBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: NotesUploadTheme.silverBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: NotesUploadTheme.textMuted)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('Save File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NotesUploadTheme.navyAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _commitSaveToFirestore(
                    subjectId: selectedSubjectId,
                    subjectName: selectedSubjectName,
                    fileName: filenameController.text.trim(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _commitSaveToFirestore({
    required String subjectId,
    required String subjectName,
    required String fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _extractedText == null) return;

    setState(() => _isSavingToSubject = true);

    try {
      final safeName = fileName.endsWith('.txt') ? fileName : '$fileName.txt';
      final preview = _extractedText!.length > 120
          ? '${_extractedText!.substring(0, 120)}...'
          : _extractedText!;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('subjects')
          .doc(subjectId)
          .collection('files')
          .add({
        'fileName': safeName,
        'fileType': 'txt',
        'extractedContent': _extractedText,
        'preview': preview,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      _snack(
        '✅ Saved "$safeName" into "$subjectName" syllabus hub!',
        Colors.green,
      );
    } catch (e) {
      _snack('Failed to save to subject: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSavingToSubject = false);
    }
  }

  void _copyToClipboard() {
    if (_extractedText == null || _extractedText!.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _extractedText!));
    _snack('Copied formulas and text to clipboard!', NotesUploadTheme.navyDark);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          msg,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotesUploadTheme.pageBg,
      body: Stack(
        children: [
          // ── Atmospheric Background Circles (Electric Blue & Silver) ──
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NotesUploadTheme.electricBlue.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 160,
            right: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NotesUploadTheme.silver.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── App Header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: NotesUploadTheme.navyDark,
                          size: 22,
                        ),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Column(
                        children: const [
                          Text(
                            'Scan & Digitize Notes',
                            style: TextStyle(
                              color: NotesUploadTheme.navyDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'English Text & Math Formulas OCR',
                            style: TextStyle(
                              color: NotesUploadTheme.electricBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 44), // Alignment balance
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Action Buttons Row ──
                  Row(
                    children: [
                      if (!kIsWeb) ...[
                        Expanded(
                          child: _gradientBtn(
                            label: 'Camera Scan',
                            icon: Icons.camera_alt_rounded,
                            colors: NotesUploadTheme.scanGradient,
                            onTap: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: NotesUploadTheme.navyDark,
                            side: const BorderSide(
                              color: NotesUploadTheme.silverBorder,
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: NotesUploadTheme.electricBlue,
                          ),
                          label: const Text(
                            'Upload Image',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Main Content Area ──
                  Expanded(
                    child: _isProcessing
                        ? _buildProcessing()
                        : _extractedText != null
                            ? _buildResultsPane()
                            : _imageBytes != null
                                ? _buildImagePreview()
                                : _buildEmptyState(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: NotesUploadTheme.electricBlue),
          SizedBox(height: 16),
          Text(
            'Analyzing document and extracting mathematical symbols…',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NotesUploadTheme.textMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: NotesUploadTheme.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NotesUploadTheme.silverBorder, width: 1.4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  NotesUploadTheme.electricBlue.withOpacity(0.2),
                  NotesUploadTheme.silver.withOpacity(0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              size: 38,
              color: NotesUploadTheme.electricBlue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Document Selected',
            style: TextStyle(
              color: NotesUploadTheme.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'Upload or snap textbook notes, handwriting, or exam formulas (supports English and mathematical symbols).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NotesUploadTheme.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: NotesUploadTheme.navyDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NotesUploadTheme.silverBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(_imageBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _gradientBtn(
          label: 'Extract Text & Math Formulas',
          icon: Icons.functions_rounded,
          colors: NotesUploadTheme.scanGradient,
          onTap: _runOcr,
        ),
      ],
    );
  }

  Widget _buildResultsPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Extracted Content',
              style: TextStyle(
                color: NotesUploadTheme.navyDark,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                // Copy Button
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: NotesUploadTheme.electricBlue,
                  ),
                  tooltip: 'Copy to clipboard',
                  onPressed: _copyToClipboard,
                ),
                // Scan New Document
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 22,
                    color: NotesUploadTheme.silver,
                  ),
                  tooltip: 'Scan New',
                  onPressed: () => setState(() {
                    _extractedText = null;
                    _imageBytes = null;
                    _imageFile = null;
                  }),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Text & Formula Display Area
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: NotesUploadTheme.silverBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: NotesUploadTheme.electricBlue.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                _extractedText!,
                style: const TextStyle(
                  color: NotesUploadTheme.navyDark,
                  fontSize: 14,
                  height: 1.6,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Save to Existing Subject Folder Button
        ElevatedButton.icon(
          onPressed: _isSavingToSubject ? null : _showSaveToSubjectDialog,
          icon: _isSavingToSubject
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.drive_folder_upload_rounded,
                  color: Colors.white),
          label: Text(
            _isSavingToSubject
                ? 'Saving to Subject...'
                : 'Save to Subject Folder',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: NotesUploadTheme.navyAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _gradientBtn({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }
}
