import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/ocr_service.dart';

/// UC-04/UC-06 Upload/Scan Notes + UC-05 Extract Text (OCR).
///
/// Mobile  — Camera OR gallery → ML Kit OCR (on-device, fast, offline)
/// Web     — Gallery upload only → AI Vision OCR (HF API, cross-platform)
///
/// On both platforms the extracted text is selectable and copyable.
class NotesUploadScreen extends StatefulWidget {
  const NotesUploadScreen({super.key});

  @override
  State<NotesUploadScreen> createState() => _NotesUploadScreenState();
}

class _NotesUploadScreenState extends State<NotesUploadScreen> {
  // Services
  final _ocrService = OcrService(); // native ML Kit — mobile only
  final _aiService = AiService(); // vision API   — web + mobile fallback

  // State
  Uint8List? _imageBytes; // used for display on all platforms
  File? _imageFile; // used for ML Kit OCR on mobile
  String? _mimeType; // passed to the vision API
  String? _extractedText;
  bool _isProcessing = false;

  // Design tokens
  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFEEEBFD);
  static const Color fieldFill = Color(0xFFF0EDFE);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF5B5E7A);

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
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
  }

  /// Derive MIME type from file extension (fallback: image/jpeg).
  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'jfif': 'image/jpeg',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    return map[ext] ?? 'image/jpeg';
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
      _extractedText = null;
    });

    try {
      String text;
      if (!kIsWeb && _imageFile != null) {
        // Mobile: fast on-device ML Kit
        text = await _ocrService.extractTextFromImage(_imageFile!);
      } else {
        // Web: AI vision model via HTTP
        text = await _aiService.extractTextFromImageBytes(
          _imageBytes!,
          mimeType: _mimeType ?? 'image/jpeg',
        );
      }
      setState(() => _extractedText =
          text.trim().isEmpty ? '(No text detected in image)' : text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('OCR failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Clipboard ─────────────────────────────────────────────────────────────

  void _copyToClipboard() {
    if (_extractedText == null || _extractedText!.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _extractedText!));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: textDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: const Row(children: [
        Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        SizedBox(width: 10),
        Text('Copied to clipboard!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    ));
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
        title: const Text('Upload / Scan Notes',
            style: TextStyle(
                color: textDark, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Action buttons row ────────────────────────────────────────
              Row(children: [
                // Camera — mobile only
                if (!kIsWeb) ...[
                  Expanded(
                    child: _gradientBtn(
                      label: 'Scan',
                      icon: Icons.camera_alt_outlined,
                      colors: const [Color(0xFF6C3CF7), Color(0xFF9B6CF9)],
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                // Gallery — all platforms
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: textDark,
                      side: BorderSide(color: primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.image_outlined,
                        size: 18, color: primary),
                    label: const Text(
                      kIsWeb
                          ? 'Upload Image  (.jpg .png .jpeg .jfif)'
                          : 'Upload',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Main content area ─────────────────────────────────────────
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
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildProcessing() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: primary),
        SizedBox(height: 16),
        const Text(
          kIsWeb
              ? 'Sending image to AI for text extraction…'
              : 'Extracting text from image…',
          style: const TextStyle(color: textMuted, fontSize: 14),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [
              primary.withValues(alpha: 0.15),
              primary.withValues(alpha: 0.05)
            ]),
          ),
          child: const Icon(Icons.document_scanner_rounded,
              size: 40, color: primary),
        ),
        const SizedBox(height: 16),
        const Text('No Document Selected',
            style: TextStyle(
                color: textDark, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: const Text(
            kIsWeb
                ? 'Upload a .jpg, .png, .jpeg or .jfif image to extract its text.'
                : 'Scan with camera or upload an image to extract text.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: textMuted, fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image thumbnail
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: textDark, borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(_imageBytes!, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Extract button — works on both platforms
        _gradientBtn(
          label: 'Extract Text',
          icon: Icons.auto_awesome_rounded,
          colors: const [Color(0xFF6C3CF7), Color(0xFF06B6D4)],
          onTap: _runOcr,
        ),
      ],
    );
  }

  Widget _buildResultsPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row with copy button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Extracted Text',
                style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Row(children: [
              // Copy All button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C3CF7), Color(0xFF06B6D4)]),
                ),
                child: TextButton.icon(
                  onPressed: _copyToClipboard,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy All',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              // Scan again
              TextButton.icon(
                onPressed: () => setState(() {
                  _extractedText = null;
                  _imageBytes = null;
                  _imageFile = null;
                }),
                style: TextButton.styleFrom(foregroundColor: textMuted),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('New',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 8),

        // Selectable text area — user can select + copy any portion
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: primary.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _extractedText!,
                style:
                    const TextStyle(color: textDark, fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Reusable gradient button ──────────────────────────────────────────────

  Widget _gradientBtn({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
              color: colors.last.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4))
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
