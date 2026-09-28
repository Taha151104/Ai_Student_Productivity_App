import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/quiz_model.dart';
import '../models/progress_model.dart';
import '../core/constants.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _aiService = AiService();
  final _firestoreService = FirestoreService();
  final _inputController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _derivedTopic;
  List<QuizQuestion> _questions = [];
  final Map<int, String> _selectedAnswers = {};
  bool _submitted = false;

  int _selectedQuestionCount = 10;
  final List<int> _countOptions = [10, 15, 20, 25, 30, 40, 50];

  String? _attachedFileName;
  Uint8List? _pdfBytes;
  String? _extractedPdfContent;
  int? _pdfFileSizeKb;

  int _tab = 0;

  static const int pointsPerCorrect = 20;
  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFF8F7FF);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF6E6B80);
  static const Color correctGreen = Color(0xFF10D9A0);
  static const Color incorrectRed = Color(0xFFFF6B7A);

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String _extractTextFromPdfBytes(Uint8List bytes) {
    try {
      final raw = latin1.decode(bytes);
      final StringBuffer buffer = StringBuffer();
      final tjRegex = RegExp(r'\(([^)]+)\)\s*(?:Tj|' r"'" r'|")');
      final matches = tjRegex.allMatches(raw);

      for (final match in matches) {
        final text = match.group(1);
        if (text != null && text.trim().isNotEmpty) {
          final cleaned =
              text.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), ' ').trim();
          if (cleaned.length > 1 &&
              !cleaned.startsWith('/') &&
              !cleaned.contains('obj')) {
            buffer.write('$cleaned ');
          }
        }
      }
      return buffer.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: <String>['pdf', 'txt'],
      );

      final XFile? file =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file != null) {
        final Uint8List bytes = await file.readAsBytes();
        final sizeKb = (bytes.lengthInBytes / 1024).round();

        setState(() {
          _attachedFileName = file.name;
          _pdfBytes = bytes;
          _pdfFileSizeKb = sizeKb;
          _error = null;
        });

        if (file.name.toLowerCase().endsWith('.txt')) {
          final content = utf8.decode(bytes, allowMalformed: true);
          _extractedPdfContent = content;
          _inputController.text =
              content.length > 5000 ? content.substring(0, 5000) : content;
          _snack('📄 Loaded text from ${file.name}', Colors.green);
        } else {
          final extracted = _extractTextFromPdfBytes(bytes);
          _extractedPdfContent = extracted;

          if (extracted.length > 80) {
            _inputController.text = extracted.length > 5000
                ? extracted.substring(0, 5000)
                : extracted;
            _snack('📄 Extracted content from ${file.name}', Colors.green);
          } else {
            if (_inputController.text.trim().isEmpty) {
              _inputController.text =
                  'Generate exam-oriented MCQs from this handout.';
            }
            _snack('📄 Attached document: ${file.name}', Colors.blue);
          }
        }
      }
    } catch (e) {
      _snack('Could not read file: $e', Colors.red);
    }
  }

  void _clearAttachedPdf() {
    setState(() {
      _attachedFileName = null;
      _pdfBytes = null;
      _extractedPdfContent = null;
      _pdfFileSizeKb = null;
      _inputController.clear();
    });
    _snack('Attachment cleared', Colors.grey);
  }

  Future<void> _generateQuiz() async {
    final userInstruction = _inputController.text.trim();

    final String studyText =
        (_extractedPdfContent != null && _extractedPdfContent!.length > 50)
            ? _extractedPdfContent!
            : userInstruction;

    final String specificScope =
        (_extractedPdfContent != null && _extractedPdfContent!.length > 50)
            ? userInstruction
            : '';

    if (studyText.isEmpty) {
      _snack(
          'Please upload a PDF handout or paste study notes.', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _questions = [];
      _selectedAnswers.clear();
      _submitted = false;

      if (_attachedFileName != null) {
        _derivedTopic = _attachedFileName!
            .replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
      } else {
        final words = userInstruction.split(RegExp(r'\s+'));
        _derivedTopic = words.take(4).join(' ') + (words.length > 4 ? '…' : '');
      }
    });

    try {
      // Passes studyText as first positional argument, followed by named parameters:
      final jsonString = await _aiService.generateQuizJson(
        studyText,
        questionCount: _selectedQuestionCount,
        userFocusInstruction: specificScope,
        topicHint: _derivedTopic,
      );

      final list = _extractJsonList(jsonString);
      if (!mounted) return;

      setState(() {
        _questions = list
            .map((q) =>
                QuizQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _extractJsonList(String raw) {
    if (raw.trim().startsWith("I don't see") ||
        raw.trim().startsWith("Please provide")) {
      throw FormatException(
        'The AI needs study notes. Please paste text or attach a readable handout.\n\nAI message: "$raw"',
      );
    }

    String cleaned = raw
        .replaceAll(RegExp(r'^\s*```(?:json)?', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    final s = cleaned.indexOf('[');
    final e = cleaned.lastIndexOf(']');
    if (s != -1 && e != -1 && e > s) {
      final substring = cleaned.substring(s, e + 1);
      final decoded = jsonDecode(substring);
      if (decoded is List) return decoded;
    }

    final decoded = jsonDecode(cleaned);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['questions'] is List) {
      return decoded['questions'] as List;
    }

    throw FormatException('Could not parse valid questions array:\n$raw');
  }

  int _computeScore() {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctAnswer) score++;
    }
    return score;
  }

  Future<void> _exportQuizAsPdf() async {
    final pdf = pw.Document();
    final topic = _derivedTopic ?? 'Exam Preparation Quiz';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AI Student Productivity Ecosystem',
                  style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  DateTime.now().toString().split(' ')[0],
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Exam Quiz: $topic',
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Questions: ${_questions.length} • Passing: 60%',
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Divider(thickness: 1.5, color: PdfColors.deepPurple),
          pw.SizedBox(height: 12),
          ...List.generate(_questions.length, (idx) {
            final q = _questions[idx];
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Q${idx + 1}. ${q.question}',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  ...q.options.map(
                    (opt) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                      child: pw.Text('• $opt',
                          style: const pw.TextStyle(fontSize: 9.5)),
                    ),
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Text('ANSWER KEY',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Q#', 'Correct Answer'],
            data: List.generate(_questions.length,
                (i) => ['Q${i + 1}', _questions[i].correctAnswer]),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Exam_Quiz_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _submitQuiz() async {
    if (_selectedAnswers.length < _questions.length) {
      _snack(
          '⚠️ Please answer all questions before submitting!', Colors.orange);
      return;
    }

    setState(() => _submitted = true);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final score = _computeScore();
    final total = _questions.length;
    final topic = _derivedTopic ?? 'Exam Oriented Quiz';

    try {
      final quizModel = QuizModel(
        quizId: '',
        noteId: '',
        questions: _questions,
        generatedAt: DateTime.now(),
      );

      final quizRef = await _firestoreService.addDocument(
        AppConstants.quizzesCollection,
        {
          ...quizModel.toMap(),
          'userId': userId,
          'topic': topic,
          'questionCount': total,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      final progressModel = ProgressModel(
        progressId: '',
        userId: userId,
        quizId: quizRef.id,
        score: score,
        totalQuestions: total,
        recordedAt: DateTime.now(),
      );

      await _firestoreService.addDocument(
        AppConstants.progressCollection,
        {
          ...progressModel.toMap(),
          'quizTopic': topic,
          'pointsEarned': score * pointsPerCorrect,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      if (mounted)
        _snack('✅ Quiz results saved! (+${score * pointsPerCorrect} pts)',
            Colors.green);
    } catch (e) {
      if (mounted) _snack('Failed to save: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
      ),
    );
  }

  void _switchTab(int next) {
    setState(() {
      _tab = next;
      _error = null;
    });
  }

  void _resetQuiz() {
    setState(() {
      _questions = [];
      _selectedAnswers.clear();
      _submitted = false;
      _derivedTopic = null;
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
        title: const Text('AI Exam Quiz Studio',
            style: TextStyle(
                color: textDark, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _switchTab(_tab == 0 ? 1 : 0),
              icon: Icon(_tab == 0 ? Icons.history_rounded : Icons.add_rounded,
                  color: primary, size: 20),
              label: Text(_tab == 0 ? 'History' : 'New Quiz',
                  style: const TextStyle(
                      color: primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _tab == 1
            ? _buildHistoryTab()
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 100.0),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: primary),
                              SizedBox(height: 16),
                              Text('Generating exam-pattern questions...',
                                  style: TextStyle(color: textMuted)),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_questions.isEmpty)
                            _buildInputPane()
                          else
                            _buildQuizPane(),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildInputPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Generate customized, exam-oriented quizzes from textbook notes or uploaded PDFs (10 to 50 questions).',
          style: TextStyle(color: textMuted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _attachedFileName ?? 'Import Study Material from PDF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _attachedFileName != null
                          ? '${_pdfFileSizeKb ?? 0} KB • Ready for exam generation'
                          : 'Tap to select PDF notes or slides',
                      style: TextStyle(
                        color: _attachedFileName != null
                            ? Colors.green.shade700
                            : textMuted,
                        fontSize: 11,
                        fontWeight: _attachedFileName != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (_attachedFileName != null)
                IconButton(
                  onPressed: _clearAttachedPdf,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey),
                  tooltip: 'Remove PDF',
                ),
              ElevatedButton.icon(
                onPressed: _pickPdfFile,
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(_attachedFileName == null ? 'Upload' : 'Change'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Number of Questions:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textDark)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$_selectedQuestionCount Questions',
                        style: const TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _countOptions.map((count) {
                    final isSelected = _selectedQuestionCount == count;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$count Qs'),
                        selected: isSelected,
                        selectedColor: primary,
                        labelStyle: TextStyle(
                            color: isSelected ? Colors.white : textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        backgroundColor: const Color(0xFFF1F0F8),
                        onSelected: (val) {
                          if (val)
                            setState(() => _selectedQuestionCount = count);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _inputController,
          maxLines: 6,
          style: const TextStyle(color: textDark, fontSize: 14),
          decoration: InputDecoration(
            hintText: _attachedFileName != null
                ? 'Optional: Specify focus or lecture (e.g. Only make MCQs from the first lecture)...'
                : 'Paste note text or lecture summaries here…',
            hintStyle: const TextStyle(color: textMuted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primary.withValues(alpha: 0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primary.withValues(alpha: 0.15))),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: primary, width: 2)),
          ),
        ),
        const SizedBox(height: 20),
        _actionButton(
            '🎯 Generate Exam Quiz ($_selectedQuestionCount Questions)',
            _generateQuiz),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12.5,
                            height: 1.4))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Topic: ${_derivedTopic ?? "Exam Quiz"}',
                  style: const TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  overflow: TextOverflow.ellipsis),
            ),
            ElevatedButton.icon(
              onPressed: _exportQuizAsPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Save as PDF'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _questions.length,
          itemBuilder: (context, qIdx) => _buildQuestionCard(qIdx),
        ),
        const SizedBox(height: 12),
        if (!_submitted)
          _actionButton('📤 Submit Answers & Score', _submitQuiz)
        else ...[
          _buildResultCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportQuizAsPdf,
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: const BorderSide(color: primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetQuiz,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('New Quiz'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildQuestionCard(int qIdx) {
    final q = _questions[qIdx];
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Question ${qIdx + 1} of ${_questions.length}',
                style: const TextStyle(
                    color: primary, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Text(q.question,
                style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 12),
            ...q.options.map((opt) => _buildOptionTile(qIdx, q, opt)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(int qIdx, QuizQuestion q, String opt) {
    final selected = _selectedAnswers[qIdx];
    final isSelected = selected == opt;

    Color optionColor = Colors.white;
    Color borderCol = primary.withValues(alpha: 0.15);
    Color textCol = textDark;

    if (_submitted) {
      if (opt == q.correctAnswer) {
        optionColor = correctGreen.withValues(alpha: 0.12);
        borderCol = correctGreen;
        textCol = Colors.green.shade800;
      } else if (isSelected && selected != q.correctAnswer) {
        optionColor = incorrectRed.withValues(alpha: 0.12);
        borderCol = incorrectRed;
        textCol = Colors.red.shade800;
      }
    } else if (isSelected) {
      optionColor = primary.withValues(alpha: 0.08);
      borderCol = primary;
      textCol = primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _submitted
            ? null
            : () => setState(() => _selectedAnswers[qIdx] = opt),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: optionColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: borderCol, width: isSelected || _submitted ? 1.5 : 1)),
          child: Text(opt,
              style: TextStyle(
                  color: textCol,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final score = _computeScore();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.2))),
      child: Column(
        children: [
          const Text('Exam Quiz Completed!',
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Score: $score / ${_questions.length}',
              style: const TextStyle(
                  color: textDark, fontWeight: FontWeight.bold, fontSize: 24)),
          Text('Earned: ${score * pointsPerCorrect} Points',
              style: const TextStyle(
                  color: correctGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.progressCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${snapshot.error}')));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No quiz records found. Take your first quiz!',
                      style: TextStyle(color: textMuted))));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final topic = data['quizTopic'] ?? 'General';
            final score = data['score'] ?? 0;
            final total = data['totalQuestions'] ?? 0;
            final points = data['pointsEarned'] ?? 0;

            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: primary.withValues(alpha: 0.08))),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(topic,
                    style: const TextStyle(
                        color: textDark, fontWeight: FontWeight.bold)),
                subtitle: Text('Score: $score/$total • Earned +$points pts',
                    style: const TextStyle(color: textMuted)),
                trailing: const Icon(Icons.assignment_turned_in_outlined,
                    color: primary),
              ),
            );
          },
        );
      },
    );
  }

  Widget _actionButton(String title, VoidCallback action) {
    return ElevatedButton(
      onPressed: action,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}
