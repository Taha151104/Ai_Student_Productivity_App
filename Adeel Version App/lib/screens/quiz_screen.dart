import 'dart:convert';
import 'dart:typed_data';
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
  bool _isExtractingFile = false;
  String _loadingStatus = 'Generating exam-pattern questions...';
  String? _error;
  String? _derivedTopic;
  List<QuizQuestion> _questions = [];
  final Map<int, String> _selectedAnswers = {};
  bool _submitted = false;

  // Question count selector (10 to 50)
  int _selectedQuestionCount = 10;
  final List<int> _countOptions = [10, 15, 20, 25, 30, 40, 50];

  // Uploaded file info
  String? _attachedFileName;

  // tab: 0 = generate, 1 = history
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

  // ── Smart File Picker & Real Content Extractor (PDF, TXT, Images) ─────────

  Future<void> _pickPdfFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Study Material (PDF, TXT, Images)',
        extensions: <String>['pdf', 'txt', 'md', 'png', 'jpg', 'jpeg'],
      );

      final XFile? file =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file == null) return;

      setState(() {
        _attachedFileName = file.name;
        _isExtractingFile = true;
        _error = null;
      });

      final Uint8List fileBytes = await file.readAsBytes();
      final String lowerName = file.name.toLowerCase();
      String extractedText = '';

      // 1. Plain Text / Markdown Files (.txt, .md)
      if (lowerName.endsWith('.txt') || lowerName.endsWith('.md')) {
        extractedText = utf8.decode(fileBytes, allowMalformed: true).trim();
      }
      // 2. Image Files (.png, .jpg, .jpeg) -> Vision OCR
      else if (lowerName.endsWith('.png') ||
          lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg')) {
        final mime = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';
        extractedText = await _aiService.extractTextFromImageBytes(
          fileBytes,
          mimeType: mime,
        );
      }
      // 3. PDF Files (.pdf) -> Render PDF pages & extract real text
      else if (lowerName.endsWith('.pdf')) {
        extractedText = await _extractRealTextFromPdf(fileBytes);
      }

      if (!mounted) return;

      final cleaned = extractedText.trim();
      if (cleaned.isNotEmpty) {
        setState(() {
          _inputController.text =
              cleaned.length > 12000 ? cleaned.substring(0, 12000) : cleaned;
        });
        _snack(
          '✅ Successfully read text from ${file.name} (${cleaned.length} chars)',
          Colors.green,
        );
      } else {
        setState(() {
          _error =
              'Could not extract readable text from ${file.name}. Try another PDF, image, or paste the text below.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to read file: $e');
        _snack('Could not read file: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isExtractingFile = false);
      }
    }
  }

  /// Extracts real readable text from a PDF file.
  /// First attempts to rasterize pages via `Printing.raster` and run Vision OCR
  /// so compressed & scanned university handouts are read accurately.
  /// Falls back to literal PDF text-block parsing if needed.
  Future<String> _extractRealTextFromPdf(Uint8List pdfBytes) async {
    final StringBuffer buffer = StringBuffer();

    // Method 1: Rasterize first 3 pages of the PDF into images and OCR them
    try {
      int pageCount = 0;
      await for (final page in Printing.raster(pdfBytes, dpi: 130)) {
        final pngBytes = await page.toPng();
        final pageText = await _aiService.extractTextFromImageBytes(
          pngBytes,
          mimeType: 'image/png',
        );
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText.trim());
          buffer.writeln();
        }
        pageCount++;
        if (pageCount >= 3) break; // Read up to 3 pages for fast response
      }
    } catch (e) {
      debugPrint('PDF raster OCR fallback notice: $e');
    }

    if (buffer.toString().trim().length > 40) {
      return buffer.toString().trim();
    }

    // Method 2: Fallback parser for uncompressed PDF text literals between BT..ET
    try {
      final rawLatin = latin1.decode(pdfBytes, allowInvalid: true);
      final btEtRegex = RegExp(r'BT[\s\S]*?ET');
      final literalRegex = RegExp(r'\(([^()\\]*(?:\\.[^()\\]*)*)\)');
      final extractedLiterals = <String>[];

      for (final block in btEtRegex.allMatches(rawLatin)) {
        final blockText = block.group(0) ?? '';
        for (final match in literalRegex.allMatches(blockText)) {
          final txt = (match.group(1) ?? '')
              .replaceAll(r'\n', '\n')
              .replaceAll(r'\r', ' ')
              .replaceAll(r'\(', '(')
              .replaceAll(r'\)', ')')
              .trim();
          if (txt.isNotEmpty &&
              !txt.startsWith('%PDF') &&
              !txt.contains('/Filter') &&
              !txt.contains('/Type')) {
            extractedLiterals.add(txt);
          }
        }
      }

      final joined = extractedLiterals.join(' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (joined.length > 40) {
        return joined;
      }
    } catch (_) {}

    return buffer.toString().trim();
  }

  // ── Quiz Generation (Strictly from Uploaded/Entered Text) ─────────────────

  Future<void> _generateQuiz() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) {
      _snack('Please upload a file or paste study text first.', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingStatus =
          'Reading study material & generating $_selectedQuestionCount questions...';
      _error = null;
      _questions = [];
      _selectedAnswers.clear();
      _submitted = false;

      if (_attachedFileName != null && _attachedFileName!.isNotEmpty) {
        _derivedTopic = _attachedFileName!.replaceAll(RegExp(r'\.[^.]+$'), '');
      } else {
        final words = raw.split(RegExp(r'\s+'));
        _derivedTopic = words.take(4).join(' ') + (words.length > 4 ? '…' : '');
      }
    });

    try {
      final List<QuizQuestion> allGeneratedQuestions = [];
      int remaining = _selectedQuestionCount;
      int batchNumber = 1;

      // Generate in batches of up to 10 so JSON never gets cut off by token limits
      while (remaining > 0) {
        final currentBatchSize = remaining > 10 ? 10 : remaining;

        if (_selectedQuestionCount > 10 && mounted) {
          setState(() {
            _loadingStatus =
                'Generating questions (${allGeneratedQuestions.length + 1} to ${allGeneratedQuestions.length + currentBatchSize} of $_selectedQuestionCount)...';
          });
        }

        final avoidExisting = allGeneratedQuestions.isEmpty
            ? ''
            : '\nDo NOT repeat these already generated questions:\n'
                '${allGeneratedQuestions.map((q) => '- ${q.question}').join('\n')}\n';

        final strictPrompt = '''
You are an university exam question generator.
Read the STUDY MATERIAL below carefully and generate MUST-KNOW multiple choice questions (MCQs) STRICTLY AND ONLY from the facts, concepts, and definitions present inside the STUDY MATERIAL.
Do NOT invent unrelated questions outside this text.

Generate exactly $currentBatchSize unique MCQs (Batch $batchNumber).$avoidExisting

Respond ONLY with a valid JSON array in this exact format (no markdown, no extra text):
[
  {
    "question": "Clear question based on the text?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": "Exact matching string from options"
  }
]

STUDY MATERIAL:
"""
$raw
"""
''';

        final jsonString = await _aiService.askChatbot(
          strictPrompt,
          systemPrompt:
              'You are a strict JSON quiz generator. You only output valid JSON arrays of multiple-choice questions based strictly on the user-provided text.',
        );

        final list = _extractJsonList(jsonString);
        final parsedBatch = list
            .map((q) =>
                QuizQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
            .where((q) => q.question.trim().isNotEmpty && q.options.isNotEmpty)
            .toList();

        if (parsedBatch.isEmpty) {
          throw Exception('AI returned an empty question list. Please try again.');
        }

        allGeneratedQuestions.addAll(parsedBatch);
        remaining -= currentBatchSize;
        batchNumber++;
      }

      if (!mounted) return;
      setState(() {
        _questions =
            allGeneratedQuestions.take(_selectedQuestionCount).toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to generate quiz: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _extractJsonList(String raw) {
    // Strip markdown code blocks if present
    String cleaned = raw
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    final s = cleaned.indexOf('[');
    final e = cleaned.lastIndexOf(']');
    if (s != -1 && e != -1 && e > s) {
      final slice = cleaned.substring(s, e + 1);
      return jsonDecode(slice) as List;
    }

    final decoded = jsonDecode(cleaned);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['questions'] is List) {
      return decoded['questions'] as List;
    }
    throw const FormatException('Could not parse quiz JSON from AI response.');
  }

  int _computeScore() {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctAnswer) score++;
    }
    return score;
  }

  // ── Save Quiz as PDF ──────────────────────────────────────────────────────

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
                    fontWeight: pw.FontWeight.bold,
                  ),
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
          pw.Text(
            'Exam Quiz: $topic',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Total Questions: ${_questions.length} • Passing standard: 60%',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.Divider(thickness: 1.5, color: PdfColors.deepPurple),
          pw.SizedBox(height: 12),
          ...List.generate(_questions.length, (idx) {
            final q = _questions[idx];
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Q${idx + 1}. ${q.question}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
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
          pw.Text(
            'ANSWER KEY',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Q#', 'Correct Answer'],
            data: List.generate(
              _questions.length,
              (i) => ['Q${i + 1}', _questions[i].correctAnswer],
            ),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Exam_Quiz_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ── Submit & save ─────────────────────────────────────────────────────────

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

      if (mounted) {
        _snack('✅ Quiz results saved to your account!', Colors.green);
      }
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
      _inputController.clear();
      _derivedTopic = null;
      _attachedFileName = null;
      _error = null;
    });
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
        title: const Text(
          'AI Exam Quiz Studio',
          style: TextStyle(
              color: textDark, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _switchTab(_tab == 0 ? 1 : 0),
              icon: Icon(
                _tab == 0 ? Icons.history_rounded : Icons.add_rounded,
                color: primary,
                size: 20,
              ),
              label: Text(
                _tab == 0 ? 'History' : 'New Quiz',
                style: const TextStyle(
                    color: primary, fontWeight: FontWeight.w600),
              ),
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
                    ? Padding(
                        padding: const EdgeInsets.only(top: 100.0),
                        child: Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: primary),
                              const SizedBox(height: 16),
                              Text(
                                _loadingStatus,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: textMuted),
                              ),
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

  // ── Input Pane ────────────────────────────────────────────────────────────

  Widget _buildInputPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload your PDF handouts, TXT notes, or lecture images. The AI will read the exact text inside your file and generate exam MCQs from it.',
          style: TextStyle(color: textMuted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 18),

        // File Attachment Card
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
                  shape: BoxShape.circle,
                ),
                child: _isExtractingFile
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: primary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded,
                        color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _attachedFileName ??
                          'Upload Study File (PDF, TXT, Image)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isExtractingFile
                          ? 'Reading text inside file, please wait...'
                          : (_attachedFileName != null
                              ? 'File text extracted & loaded below!'
                              : 'Tap Upload to read PDF, TXT, or Image notes'),
                      style: TextStyle(
                        color: _isExtractingFile ? primary : textMuted,
                        fontSize: 11,
                        fontWeight: _isExtractingFile
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isExtractingFile ? null : _pickPdfFile,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
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

        // Question Count Selector (10 to 50)
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
                  const Text(
                    'Number of Questions:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textDark),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_selectedQuestionCount Questions',
                      style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
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
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFFF1F0F8),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedQuestionCount = count);
                          }
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

        // Extracted / Pasted Notes Field
        TextField(
          controller: _inputController,
          maxLines: 8,
          style: const TextStyle(color: textDark, fontSize: 13.5),
          decoration: InputDecoration(
            hintText:
                'Uploaded file text will appear here automatically, or you can paste your lecture notes directly…',
            hintStyle: const TextStyle(color: textMuted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primary.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _actionButton(
          _isExtractingFile
              ? '⏳ Reading Uploaded File...'
              : '🎯 Generate Exam Quiz ($_selectedQuestionCount Questions)',
          _isExtractingFile ? () {} : _generateQuiz,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  // ── Quiz Pane ─────────────────────────────────────────────────────────────

  Widget _buildQuizPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Topic: ${_derivedTopic ?? "Exam Quiz"}',
                style: const TextStyle(
                    color: textDark, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
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
                    borderRadius: BorderRadius.circular(10)),
              ),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
        side: BorderSide(color: primary.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${qIdx + 1} of ${_questions.length}',
              style: const TextStyle(
                  color: primary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              q.question,
              style: const TextStyle(
                  color: textDark, fontWeight: FontWeight.w600, fontSize: 15),
            ),
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
              color: borderCol,
              width: isSelected || _submitted ? 1.5 : 1,
            ),
          ),
          child: Text(
            opt,
            style: TextStyle(
              color: textCol,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
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
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text('Exam Quiz Completed!',
              style: TextStyle(color: textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Score: $score / ${_questions.length}',
            style: const TextStyle(
                color: textDark, fontWeight: FontWeight.bold, fontSize: 24),
          ),
          Text(
            'Earned: ${score * pointsPerCorrect} Points',
            style: const TextStyle(
                color: correctGreen, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── History Pane ──────────────────────────────────────────────────────────

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
              padding: EdgeInsets.all(24),
              child: Text('No quiz records found. Take your first quiz!',
                  style: TextStyle(color: textMuted)),
            ),
          );
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
                side: BorderSide(color: primary.withValues(alpha: 0.08)),
              ),
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