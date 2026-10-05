import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../services/ai_service.dart';
import '../models/quiz_model.dart';
import '../models/progress_model.dart';
import '../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT QUIZ THEME & YELLOW PASTEL PALETTE RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class QuizTheme {
  static const Color pageBg = Colors.white;
  static const Color brightYellow = Color(0xFFFFD600);
  static const Color primaryYellow = Color(0xFFFACC15);
  static const Color pastelButtercup = Color(0xFFFEF08A);
  static const Color pastelLemon = Color(0xFFFEF9C3);
  static const Color pastelCream = Color(0xFFFFFBEB);
  static const Color yellowBorder = Color(0xFFFDE047);
  static const Color darkGoldText = Color(0xFF854D0E);
  static const Color textDark = Color(0xFF1E1348);
  static const Color textMuted = Color(0xFF64748B);
  static const Color correctGreen = Color(0xFF10B981);
  static const Color incorrectRed = Color(0xFFEF4444);

  static const List<Color> yellowGradient = [
    Color(0xFFFFEA00),
    Color(0xFFFACC15),
  ];
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _aiService = AiService();
  final _inputController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isExtractingFile = false;
  String? _error;
  String? _derivedTopic;
  String? _attachedFileName;
  String? _attachedStudyText;
  String? _fileReadWarning;
  List<QuizQuestion> _questions = [];
  final Map<int, String> _selectedAnswers = {};
  bool _submitted = false;

  int _selectedQuestionCount = 10;
  final List<int> _countOptions = [10, 15, 20, 25, 30];

  String? _selectedSubjectId;
  String? _selectedSubjectName;
  int _tab = 0; // 0: Quiz, 1: History

  static const int pointsPerCorrect = 20;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _pickStudyFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Study material',
        extensions: ['pdf', 'txt', 'md', 'png', 'jpg', 'jpeg'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null || !mounted) return;

      setState(() {
        _isExtractingFile = true;
        _error = null;
        _fileReadWarning = null;
      });

      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final String extractedText;
      if (extension == 'pdf') {
        extractedText = await _extractPdfText(bytes, file.name);
      } else if (extension == 'txt' || extension == 'md') {
        extractedText = utf8.decode(bytes, allowMalformed: true).trim();
      } else if (extension == 'png' ||
          extension == 'jpg' ||
          extension == 'jpeg') {
        extractedText = await _aiService.extractTextFromImageBytes(
          bytes,
          mimeType: extension == 'png' ? 'image/png' : 'image/jpeg',
        );
      } else {
        throw const FormatException(
            'Choose a PDF, text, Markdown, or image file.');
      }

      final cleanedText = extractedText.trim();
      if (cleanedText.length < 80) {
        throw const FormatException(
          'The file did not contain enough readable study material. '
          'Try a text-based PDF or a clearer scan.',
        );
      }

      if (!mounted) return;
      setState(() {
        _attachedFileName = file.name;
        _attachedStudyText = cleanedText;
      });
      _snack('Read study content from ${file.name}.', Colors.green);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not read study material: $error');
      }
    } finally {
      if (mounted) setState(() => _isExtractingFile = false);
    }
  }

  Future<String> _extractPdfText(Uint8List bytes, String fileName) async {
    await pdfrx.pdfrxFlutterInitialize();
    final document =
        await pdfrx.PdfDocument.openData(bytes, sourceName: fileName);
    final pageTexts = List<String>.filled(document.pages.length, '');
    try {
      for (var index = 0; index < document.pages.length; index++) {
        final pageText = await document.pages[index].loadText();
        pageTexts[index] = pageText?.fullText.trim() ?? '';
      }

      if (pageTexts.join().trim().length < 80) {
        var pagesOcrAttempted = 0;
        for (var index = 0; index < pageTexts.length; index++) {
          if (pageTexts[index].isNotEmpty) continue;
          if (pagesOcrAttempted >= 20) {
            _fileReadWarning =
                'Scanned-page OCR is limited to 20 pages per PDF.';
            break;
          }
          pagesOcrAttempted++;
          try {
            final pageImage = await document.pages[index]
                .render(fullWidth: 1400, fullHeight: 1800);
            if (pageImage == null) continue;
            Uint8List? pngBytes;
            try {
              final image = await pageImage.createImage();
              try {
                final png =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                pngBytes = png?.buffer.asUint8List();
              } finally {
                image.dispose();
              }
            } finally {
              pageImage.dispose();
            }
            if (pngBytes == null) continue;
            final recognizedText = await _aiService
                .extractTextFromImageBytes(pngBytes, mimeType: 'image/png')
                .timeout(const Duration(seconds: 30));
            pageTexts[index] = recognizedText.trim();
          } catch (error) {
            _fileReadWarning =
                'Some scanned PDF pages could not be read: $error';
          }
        }
      }

      return [
        for (var index = 0; index < pageTexts.length; index++)
          if (pageTexts[index].isNotEmpty)
            '[Page ${index + 1}]\n${pageTexts[index]}',
      ].join('\n\n');
    } finally {
      document.dispose();
    }
  }

  // Strip document-property headers without removing metadata as a study topic.
  String _scrubDocumentMetadata(String rawText) {
    final lines = rawText.split(RegExp(r'[\r\n]+'));
    final cleaned = <String>[];

    for (final line in lines) {
      final l = line.toLowerCase().trim();
      if (l.isEmpty) continue;
      if (RegExp(
            r'^(application|text|image|audio|video|font)/[\w.+-]+$|'
            r'^(content-type|creator|producer|author|creationdate|moddate|'
            r'xmlns|file|title|subject|keywords|pdf-version)\s*:',
            caseSensitive: false,
          ).hasMatch(l) ||
          l.startsWith('endobj') ||
          l.startsWith('<< /type /') ||
          l.startsWith('%pdf-')) {
        continue;
      }
      cleaned.add(line);
    }
    return cleaned.join('\n').trim();
  }

  bool _containsDocumentMetadataQuestion(QuizQuestion question) {
    final questionText = question.question.toLowerCase();
    final asksAboutMetadata = RegExp(
      r'\b(file|document)\s+(format|type|creator|author|metadata|properties)\b|'
      r'\b(format|type|creator|author)\s+of\s+(the\s+)?document\b|'
      r'\bmime\s+type\b',
    ).hasMatch(questionText);
    final hasMimeTypeOption = question.options.any(
      (option) => RegExp(
        r'^\s*(application|text|image|audio|video|font)/[\w.+-]+',
        caseSensitive: false,
      ).hasMatch(option),
    );

    return asksAboutMetadata || hasMimeTypeOption;
  }

  // ── Quiz Generation with Airtight Academic Guardrails ──────────────────────
  Future<void> _generateQuiz() async {
    final userPrompt = _inputController.text.trim();
    final user = _auth.currentUser;

    if (user == null) {
      _snack('Please log in to generate quizzes.', Colors.red);
      return;
    }

    if (_selectedSubjectId == null && _attachedStudyText == null) {
      _snack(
        'Select a subject folder or upload study material.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _questions = [];
      _selectedAnswers.clear();
      _submitted = false;
    });

    try {
      String knowledgeBaseText = _attachedStudyText ?? '';
      final subjectName = _selectedSubjectName ??
          (_attachedFileName?.replaceAll(RegExp(r'\.[^.]+$'), '') ??
              'Uploaded material');
      String topicName = subjectName;

      // 1. Fetch text from selected Subject Folder in Firestore
      if (_selectedSubjectId != null) {
        final filesSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(_selectedSubjectId)
            .collection('files')
            .orderBy('uploadedAt', descending: true)
            .get();

        final buffer = StringBuffer();
        for (final doc in filesSnap.docs) {
          final data = doc.data();
          final content = data['extractedContent'] ?? '';
          final text = content.toString().trim();
          if (text.isNotEmpty) buffer.writeln(text);
        }
        if (buffer.isNotEmpty) {
          knowledgeBaseText = [
            knowledgeBaseText,
            buffer.toString().trim(),
          ].where((text) => text.isNotEmpty).join('\n\n');
        }
      }

      // Clean out metadata
      knowledgeBaseText = _scrubDocumentMetadata(knowledgeBaseText);

      if (knowledgeBaseText.length < 80) {
        throw const FormatException(
          'There is not enough readable study text in this subject folder. '
          'Upload a readable PDF, DOCX, TXT file, or a clear image of your notes, then try again.',
        );
      }

      if (userPrompt.isNotEmpty) topicName = '$subjectName • $userPrompt';

      setState(() => _derivedTopic = topicName);

      final responseText = await _aiService.generateQuizJson(
        knowledgeBaseText,
        questionCount: _selectedQuestionCount,
        userFocusInstruction: userPrompt.isEmpty ? null : userPrompt,
      );

      final list = _extractJsonList(responseText);
      if (list.isEmpty) throw const FormatException('No questions generated');

      final questions = list.map((rawQuestion) {
        if (rawQuestion is! Map) {
          throw const FormatException('A generated question was invalid.');
        }
        final questionMap = Map<String, dynamic>.from(rawQuestion);
        final question = QuizQuestion.fromMap(questionMap);
        return question;
      }).toList();

      if (questions.length != _selectedQuestionCount ||
          questions.any((question) =>
              question.question.trim().isEmpty ||
              question.options.length != 4 ||
              question.options.toSet().length != 4 ||
              question.options.any((option) => option.trim().isEmpty) ||
              !question.options.contains(question.correctAnswer) ||
              _containsDocumentMetadataQuestion(question))) {
        throw const FormatException(
          'The generated questions were not valid and syllabus-focused. '
          'Please check that your uploaded notes contain readable course material and try again.',
        );
      }

      if (!mounted) return;

      setState(() {
        _questions = questions;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _repairJsonCandidate(String raw) {
    String cleaned = raw
        .replaceAll(RegExp(r'^\s*```(?:json)?', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    final firstBracket = cleaned.indexOf('[');
    final firstBrace = cleaned.indexOf('{');
    final start = [firstBracket, firstBrace]
        .where((index) => index != -1)
        .fold<int?>(null, (best, index) => best == null || index < best ? index : best);

    if (start != null) {
      final lastBracket = cleaned.lastIndexOf(']');
      final lastBrace = cleaned.lastIndexOf('}');
      final end = [lastBracket, lastBrace]
          .where((index) => index != -1)
          .fold<int?>(null, (best, index) => best == null || index > best ? index : best);

      if (end != null && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
    }

    cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;
    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      if (char == '\\') {
        buffer.write(char);
        escaped = true;
        continue;
      }
      if (char == '"') {
        buffer.write(char);
        inString = !inString;
        continue;
      }
      if (!inString && (char == '_' || RegExp(r'[A-Za-z]').hasMatch(char))) {
        final startIndex = i;
        var endIndex = i + 1;
        while (endIndex < cleaned.length &&
            (RegExp(r'[A-Za-z0-9_]').hasMatch(cleaned[endIndex]))) {
          endIndex++;
        }
        final token = cleaned.substring(startIndex, endIndex);
        var nextIndex = endIndex;
        while (nextIndex < cleaned.length &&
            cleaned[nextIndex].trim().isEmpty) {
          nextIndex++;
        }
        if (nextIndex < cleaned.length && cleaned[nextIndex] == ':') {
          buffer.write('"$token"');
          i = endIndex - 1;
          continue;
        }
        buffer.write(token);
        i = endIndex - 1;
        continue;
      }
      buffer.write(char);
    }

    return buffer.toString();
  }

  List<dynamic> _extractJsonList(String raw) {
    final candidates = <String>[
      _repairJsonCandidate(raw),
    ];

    final starts = <int>[];
    var searchIndex = 0;
    while (true) {
      final index = raw.indexOf('[', searchIndex);
      if (index == -1) break;
      starts.add(index);
      searchIndex = index + 1;
    }

    for (final start in starts) {
      final end = raw.lastIndexOf(']', start);
      if (end > start) {
        candidates.add(_repairJsonCandidate(raw.substring(start, end + 1)));
      }
    }

    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['questions'] is List) {
          return decoded['questions'] as List;
        }
      } catch (_) {}
    }

    throw const FormatException('Could not parse valid exam questions.');
  }

  int _computeScore() {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctAnswer) score++;
    }
    return score;
  }

  // ── Export Quiz to PDF (Fixed line with pw.CrossAxisAlignment) ──────────────
  Future<void> _exportQuizAsPdf() async {
    final pdf = pw.Document();
    final topic = _derivedTopic ?? 'Curriculum Exam Quiz';

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
                  'AI Student Productivity Portal',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.amber800,
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
          pw.Text('Subject Quiz: $topic',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              'Total Questions: ${_questions.length} • Standard Exam Pattern',
              style:
                  const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700)),
          pw.Divider(thickness: 1.5, color: PdfColors.amber700),
          pw.SizedBox(height: 12),
          ...List.generate(_questions.length, (idx) {
            final q = _questions[idx];
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                // ✅ FIXED: Added pw. prefix so there is no compile error
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
          pw.Text('OFFICIAL ANSWER KEY',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Question #', 'Correct Option'],
            data: List.generate(
              _questions.length,
              (i) => ['Q${i + 1}', _questions[i].correctAnswer],
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.amber800),
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

  // ── Submit Quiz & Save Progress ───────────────────────────────────────────
  Future<void> _submitQuiz() async {
    if (_selectedAnswers.length < _questions.length) {
      _snack(
          '⚠️ Please answer all questions before submitting!', Colors.orange);
      return;
    }

    setState(() => _submitted = true);
    final user = _auth.currentUser;
    if (user == null) return;

    final score = _computeScore();
    final total = _questions.length;
    final topic = _derivedTopic ?? 'Exam Oriented Quiz';

    try {
      final quizModel = QuizModel(
        quizId: '',
        noteId: _selectedSubjectId ?? '',
        questions: _questions,
        generatedAt: DateTime.now(),
      );

      final firestore = FirebaseFirestore.instance;
      final quizRef =
          firestore.collection(AppConstants.quizzesCollection).doc();
      final progressRef =
          firestore.collection(AppConstants.progressCollection).doc();

      final progressModel = ProgressModel(
        progressId: '',
        userId: user.uid,
        quizId: quizRef.id,
        score: score,
        totalQuestions: total,
        recordedAt: DateTime.now(),
      );

      final batch = firestore.batch();
      batch.set(quizRef, {
        ...quizModel.toMap(),
        'userId': user.uid,
        'topic': topic,
        'subjectId': _selectedSubjectId,
        'subjectName': _selectedSubjectName,
        'questionCount': total,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(progressRef, {
        ...progressModel.toMap(),
        'quizTopic': topic,
        'subjectId': _selectedSubjectId,
        'subjectName': _selectedSubjectName,
        'pointsEarned': score * pointsPerCorrect,
        'recordedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _snack(
          '✅ Quiz recorded! (+${score * pointsPerCorrect} pts)', Colors.green);
    } catch (e) {
      _snack('Failed to record: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
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

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuizTheme.pageBg,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: QuizTheme.pastelButtercup.withOpacity(0.45),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: QuizTheme.pastelLemon.withOpacity(0.6),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: QuizTheme.textDark, size: 22),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Text(
                        _tab == 0 ? 'AI Exam Quiz Studio' : 'Quiz History',
                        style: const TextStyle(
                          color: QuizTheme.textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _tab = _tab == 0 ? 1 : 0),
                        icon: Icon(
                          _tab == 0 ? Icons.history_rounded : Icons.add_rounded,
                          color: QuizTheme.darkGoldText,
                          size: 19,
                        ),
                        label: Text(
                          _tab == 0 ? 'History' : 'New Quiz',
                          style: const TextStyle(
                            color: QuizTheme.darkGoldText,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Expanded(
                  child: _tab == 1
                      ? _buildHistoryTab()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
                          child: _isLoading
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 80.0),
                                  child: Center(
                                    child: Column(
                                      children: const [
                                        CircularProgressIndicator(
                                            color: QuizTheme.primaryYellow),
                                        SizedBox(height: 16),
                                        Text(
                                          'Reading study material & preparing exam questions...',
                                          style: TextStyle(
                                            color: QuizTheme.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_questions.isEmpty)
                                      _buildInputPane()
                                    else
                                      _buildQuizPane(),
                                  ],
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPane() {
    final user = _auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Generate tailored questions from a subject folder or material you upload here.',
          style:
              TextStyle(color: QuizTheme.textMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: QuizTheme.pastelCream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuizTheme.yellowBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded,
                  color: QuizTheme.darkGoldText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _attachedFileName ?? 'Add a PDF, text file, or image',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuizTheme.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed:
                    _isExtractingFile || _isLoading ? null : _pickStudyFile,
                child: Text(_isExtractingFile ? 'Reading…' : 'Choose file'),
              ),
              if (_attachedStudyText != null)
                IconButton(
                  tooltip: 'Remove uploaded material',
                  onPressed: () {
                    setState(() {
                      _attachedFileName = null;
                      _attachedStudyText = null;
                      _fileReadWarning = null;
                    });
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        if (_fileReadWarning != null) ...[
          const SizedBox(height: 8),
          Text(
            _fileReadWarning!,
            style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: QuizTheme.pastelButtercup,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuizTheme.yellowBorder, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: QuizTheme.primaryYellow.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: QuizTheme.yellowGradient),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open_rounded,
                        color: QuizTheme.textDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Target Subject Folder',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: QuizTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (user == null)
                const Text('Log in to load your subjects.')
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('subjects')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Text(
                        'Create a subject folder in Subjects Hub and upload course notes to generate a syllabus-based quiz.',
                        style:
                            TextStyle(color: QuizTheme.textMuted, fontSize: 12),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedSubjectId,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: QuizTheme.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: QuizTheme.yellowBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: QuizTheme.yellowBorder),
                        ),
                      ),
                      hint:
                          const Text('Select Subject (e.g. MCM301, CS101...)'),
                      items: docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'Unnamed Subject';
                        return DropdownMenuItem<String>(
                            value: d.id, child: Text(name));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedSubjectId = val;
                          final match = docs.firstWhere((d) => d.id == val);
                          final data = match.data() as Map<String, dynamic>;
                          _selectedSubjectName = data['name'];
                        });
                      },
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: QuizTheme.pastelLemon,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuizTheme.yellowBorder, width: 1.4),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: QuizTheme.textDark,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: QuizTheme.yellowBorder),
                    ),
                    child: Text(
                      '$_selectedQuestionCount Qs',
                      style: const TextStyle(
                        color: QuizTheme.darkGoldText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
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
                        label: Text('$count Questions'),
                        selected: isSelected,
                        selectedColor: QuizTheme.primaryYellow,
                        labelStyle: TextStyle(
                          color: QuizTheme.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? QuizTheme.primaryYellow
                              : QuizTheme.yellowBorder,
                          width: 1.2,
                        ),
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
        const SizedBox(height: 16),
        TextField(
          controller: _inputController,
          maxLines: 4,
          style: const TextStyle(color: QuizTheme.textDark, fontSize: 14),
          decoration: InputDecoration(
            hintText:
                'Describe the quiz you want (e.g. “Cover chapter 1 only; focus on definitions and application questions”). The questions will use only the selected folder’s extracted syllabus text.',
            hintStyle:
                const TextStyle(color: QuizTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: QuizTheme.yellowBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: QuizTheme.yellowBorder),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              borderSide: BorderSide(color: QuizTheme.primaryYellow, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: QuizTheme.yellowGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: QuizTheme.primaryYellow.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _generateQuiz,
            icon: const Icon(Icons.emoji_events_rounded,
                color: QuizTheme.textDark),
            label: Text(
              'Generate Exam Quiz ($_selectedQuestionCount Questions)',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: QuizTheme.textDark,
                letterSpacing: -0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 12.5,
                        height: 1.4),
                  ),
                ),
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
              child: Text(
                'Topic: ${_derivedTopic ?? "Exam Quiz"}',
                style: const TextStyle(
                  color: QuizTheme.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _exportQuizAsPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded,
                  size: 16, color: QuizTheme.textDark),
              label: const Text('Save as PDF',
                  style: TextStyle(
                      color: QuizTheme.textDark, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuizTheme.primaryYellow,
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
        const SizedBox(height: 14),
        if (!_submitted)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: QuizTheme.yellowGradient),
              boxShadow: [
                BoxShadow(
                  color: QuizTheme.primaryYellow.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _submitQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Submit Answers & Score',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: QuizTheme.textDark),
              ),
            ),
          )
        else ...[
          _buildResultCard(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportQuizAsPdf,
                  icon: const Icon(Icons.download_rounded,
                      color: QuizTheme.darkGoldText),
                  label: const Text('Download PDF',
                      style: TextStyle(
                          color: QuizTheme.darkGoldText,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: QuizTheme.primaryYellow, width: 1.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient:
                        const LinearGradient(colors: QuizTheme.yellowGradient),
                  ),
                  child: ElevatedButton(
                    onPressed: _resetQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'New Quiz',
                      style: TextStyle(
                          color: QuizTheme.textDark,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuestionCard(int qIdx) {
    final q = _questions[qIdx];
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: QuizTheme.yellowBorder, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${qIdx + 1} of ${_questions.length}',
              style: const TextStyle(
                color: QuizTheme.darkGoldText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              q.question,
              style: const TextStyle(
                color: QuizTheme.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
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
    Color borderCol = const Color(0xFFE2E8F0);
    Color textCol = QuizTheme.textDark;

    if (_submitted) {
      if (opt == q.correctAnswer) {
        optionColor = QuizTheme.correctGreen.withOpacity(0.12);
        borderCol = QuizTheme.correctGreen;
        textCol = Colors.green.shade800;
      } else if (isSelected && selected != q.correctAnswer) {
        optionColor = QuizTheme.incorrectRed.withOpacity(0.12);
        borderCol = QuizTheme.incorrectRed;
        textCol = Colors.red.shade800;
      }
    } else if (isSelected) {
      optionColor = QuizTheme.pastelButtercup;
      borderCol = QuizTheme.primaryYellow;
      textCol = QuizTheme.textDark;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: _submitted
            ? null
            : () => setState(() => _selectedAnswers[qIdx] = opt),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final score = _computeScore();
    final percentage = ((score / _questions.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuizTheme.pastelButtercup,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuizTheme.yellowBorder, width: 1.4),
      ),
      child: Column(
        children: [
          const Text(
            'Exam Quiz Evaluation',
            style: TextStyle(
                color: QuizTheme.textDark, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Score: $score / ${_questions.length} ($percentage%)',
            style: const TextStyle(
              color: QuizTheme.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Earned +${score * pointsPerCorrect} Academic Points',
            style: const TextStyle(
              color: QuizTheme.correctGreen,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── Last 10 Quizzes History Tab (Robust In-Memory Sort) ────────────────────
  Widget _buildHistoryTab() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Log in to view quiz history.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.progressCollection)
          .where('userId', isEqualTo: user.uid)
          .orderBy('recordedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading history: ${snapshot.error}'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: QuizTheme.primaryYellow),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        if (rawDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 54,
                    color: QuizTheme.primaryYellow.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No quiz records yet.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: QuizTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Take your first quiz from your course handouts to view past attempts!',
                    style:
                        TextStyle(color: QuizTheme.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        final top10Docs = rawDocs;

        return ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: top10Docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = top10Docs[index].data() as Map<String, dynamic>;
            final topic = data['quizTopic'] ?? 'Exam Quiz';
            final score = data['score'] ?? 0;
            final total = data['totalQuestions'] ?? 0;
            final points = data['pointsEarned'] ?? 0;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: QuizTheme.yellowBorder),
                boxShadow: [
                  BoxShadow(
                    color: QuizTheme.primaryYellow.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: QuizTheme.pastelButtercup,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: QuizTheme.yellowBorder),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: QuizTheme.textDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: QuizTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Score: $score/$total • +$points pts earned',
                          style: const TextStyle(
                            color: QuizTheme.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: QuizTheme.correctGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${((score / (total > 0 ? total : 1)) * 100).round()}%',
                      style: const TextStyle(
                        color: QuizTheme.correctGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
