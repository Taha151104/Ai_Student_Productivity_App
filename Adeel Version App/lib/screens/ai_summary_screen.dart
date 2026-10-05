import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';

/// UC-08/UC-17 Generate + View Summary.
/// SRS 2.3: supports a choice between short and detailed summary formats.
class AiSummaryScreen extends StatefulWidget {
  const AiSummaryScreen({super.key});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  final _aiService = AiService();
  final _inputController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _summary;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  // 'short' or 'detailed'. Drives both the prompt sent to the AI
  // service and what gets stored alongside the saved summary.
  String _summaryFormat = 'short';

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFEEEBFD);
  static const Color fieldFill = Color(0xFFF0EDFE);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF5B5E7A);

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    if (_inputController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _summary = null;
    });
    try {
      final result = await _aiService.generateSummary(
        _inputController.text.trim(),
        format: _summaryFormat,
      );
      setState(() => _summary = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSummary() async {
    if (_summary == null) return;
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to save.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('summaries').add({
        'userId': user.uid,
        'originalText': _inputController.text.trim(),
        'summaryText': _summary!.trim(),
        'format': _summaryFormat,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF1A1040),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Text('Summary saved!',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ]),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1A1040),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: const Row(children: [
        Icon(Icons.content_copy, color: Colors.blueAccent, size: 20),
        SizedBox(width: 10),
        Text('Copied!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    ));
  }

  /// Switching format after a summary is already showing clears the old
  /// result — mixing an old "short" result with a newly selected
  /// "detailed" toggle would be confusing/misleading.
  void _setFormat(String format) {
    if (_summaryFormat == format) return;
    setState(() {
      _summaryFormat = format;
      _summary = null;
      _error = null;
    });
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
        title: const Text('AI Summary',
            style: TextStyle(
                color: textDark, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Input
            TextField(
              controller: _inputController,
              maxLines: 7,
              style: const TextStyle(color: textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Paste or extract note text here…',
                hintStyle: const TextStyle(color: textMuted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: primary.withValues(alpha: 0.2))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: primary.withValues(alpha: 0.2))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: primary, width: 2)),
              ),
            ),
            const SizedBox(height: 16),

            // Format toggle: Short vs Detailed
            const Text('Summary Format',
                style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _formatChip(
                    label: '⚡ Short',
                    value: 'short',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _formatChip(
                    label: '📖 Detailed',
                    value: 'detailed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Generate button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                    colors: [Color(0xFFF472B6), Color(0xFF9B6CF9)]),
                boxShadow: [
                  BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6))
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateSummary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : Text(
                        _summaryFormat == 'short'
                            ? '✨ Generate Short Summary'
                            : '✨ Generate Detailed Summary',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
              ),
            ],

            // Summary result
            if (_summary != null) ...[
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Text('Summary Result',
                      style: TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _summaryFormat == 'short' ? 'Short' : 'Detailed',
                      style: const TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
                TextButton.icon(
                  onPressed: () => _copy(_summary!),
                  style: TextButton.styleFrom(foregroundColor: primary),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: SelectableText(_summary!,
                    style: const TextStyle(
                        color: textDark, fontSize: 14, height: 1.55)),
              ),
              const SizedBox(height: 16),

              // Save button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C3CF7), Color(0xFF06B6D4)]),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.bookmark_rounded, size: 18),
                  label: const Text('Save Summary',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _formatChip({required String label, required String value}) {
    final selected = _summaryFormat == value;
    return InkWell(
      onTap: () => _setFormat(value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : textDark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
