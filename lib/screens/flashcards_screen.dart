import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT FLASHCARDS THEME & ORANGE / COPPER PALETTE RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class FlashcardsTheme {
  static const Color pageBg = Colors.white; // Pure White Canvas
  static const Color brightOrange =
      Color(0xFFEA580C); // Bright Orange Action Primary
  static const Color neonOrange = Color(0xFFFF9100); // Vivid Radiant Orange
  static const Color pastelOrangeCard =
      Color(0xFFFED7AA); // Soft Pastel Orange Card Fill
  static const Color pastelAnswerCard =
      Color(0xFFFFEDD5); // Soft Cream-Orange Answer Fill
  static const Color orangeBorder = Color(0xFFFDBA74); // Vibrant Orange Outline
  static const Color copperAccent =
      Color(0xFFC2410C); // Metallic Antique Copper
  static const Color copperDark = Color(0xFF9A3412); // Deep Copper Bronze Text
  static const Color textDark = Color(0xFF1E1348); // Deep Navy Black Text
  static const Color textMuted = Color(0xFF64748B); // Slate Muted Text

  // Bright Orange & Copper Gradients
  static const List<Color> orangeButtonGradient = [
    Color(0xFFFF9100), // Bright Orange
    Color(0xFFEA580C), // Saturated Tangerine Orange
  ];

  static const List<Color> questionCardGradient = [
    Color(0xFFFED7AA), // Pastel Peach
    Color(0xFFFDBA74), // Warm Pastel Orange
  ];

  static const List<Color> answerCardGradient = [
    Color(0xFFFFF7ED), // Warm Cream
    Color(0xFFFFEDD5), // Soft Apricot
  ];
}

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _aiService = AiService();
  final _auth = FirebaseAuth.instance;
  final _topicController = TextEditingController();
  final GlobalKey _cardBoundaryKey = GlobalKey();

  List<Map<String, String>> _flashcards = [
    {
      'question': 'What is Object-Oriented Programming (OOP)?',
      'answer':
          'A programming paradigm based on "objects", containing attributes (data) and methods (code). Core pillars: Encapsulation, Inheritance, Polymorphism, and Abstraction.',
      'subject': 'CS101 Concept',
    },
    {
      'question': 'Explain the difference between a Stack and a Queue.',
      'answer':
          'A Stack follows LIFO (Last-In, First-Out), whereas a Queue operates on FIFO (First-In, First-Out).',
      'subject': 'Data Structures',
    },
    {
      'question': 'What is Database Normalization (1NF to 3NF)?',
      'answer':
          'The process of organizing tables to eliminate data redundancy and prevent update/delete anomalies.',
      'subject': 'Database Systems',
    },
  ];

  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // ── AI Generation with Subject Folder Grounding ───────────────────────────
  Future<void> _generateFlashcardsFromSubject({
    required String? subjectId,
    required String? subjectName,
    required String userPrompt,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _snack('Please log in to load subject notes.', Colors.red);
      return;
    }

    if (userPrompt.trim().isEmpty && subjectId == null) {
      _snack('Please select a subject folder or type a topic.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String subjectNotes = '';

      // 1. Pull syllabus notes from the selected Subject Folder in Firestore
      if (subjectId != null) {
        final filesSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('subjects')
            .doc(subjectId)
            .collection('files')
            .limit(6)
            .get();

        final buffer = StringBuffer();
        for (final doc in filesSnap.docs) {
          final data = doc.data();
          final content = data['extractedContent'] ?? data['preview'] ?? '';
          if (content.toString().trim().isNotEmpty) {
            buffer.writeln(content);
          }
        }
        subjectNotes = buffer.toString().trim();
      }

      final targetName = subjectName ?? 'General Course';

      // 2. Clear instructions for Flashcard Q&A format
      final prompt = '''
STUDENT'S UPLOADED SUBJECT REPOSITORY FOR ($targetName):
"""
${subjectNotes.isNotEmpty ? subjectNotes : 'Subject: ' + targetName}
"""

STUDENT'S FOCUS INSTRUCTION:
"$userPrompt"

TASK:
Generate exactly 6 high-yield revision flashcards for this student based on their requested chapter and subject notes above.
Return ONLY a valid JSON array of objects. Do not include markdown codeblocks or extra text.
Format:
[
  {"question": "What is ...?", "answer": "Explanation...", "subject": "$targetName"}
]
''';

      // 3. Call askChatbot for reliable, unformatted JSON response
      final res = await _aiService.askChatbot(
        prompt,
        systemPrompt:
            'You are an exam revision flashcard generator. You only respond with a raw JSON array of flashcard objects.',
      );

      final list = _extractJsonList(res);

      if (list.isEmpty) {
        throw const FormatException('No cards generated');
      }

      if (!mounted) return;
      setState(() {
        _flashcards = list.map((item) {
          final m = item as Map<String, dynamic>;
          return {
            'question': m['question']?.toString() ?? 'Exam Question',
            'answer': m['answer']?.toString() ?? 'Key concept answer',
            'subject': m['subject']?.toString() ?? targetName,
          };
        }).toList();
        _currentIndex = 0;
        _showAnswer = false;
      });

      _snack(
          '✅ Generated ${_flashcards.length} new flashcards for $targetName!',
          Colors.green);
    } catch (e) {
      debugPrint('Flashcard error: $e');
      _snack('Could not generate from subject: $e', Colors.red);
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
        if (decoded is Map && decoded['flashcards'] is List) {
          return decoded['flashcards'] as List;
        }
      } catch (_) {}
    }

    return [];
  }

  // ── Save Current Flashcard As Image (PNG) ──────────────────────────────────
  Future<void> _saveFlashcardAsImage() async {
    try {
      final boundary = _cardBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      await Printing.sharePdf(
        bytes: pngBytes,
        filename: 'Flashcard_${_currentIndex + 1}.png',
      );

      _snack('📸 Flashcard image saved!', Colors.green);
    } catch (e) {
      _snack('Could not export image: $e', Colors.red);
    }
  }

  void _openCreateSheet() {
    final user = _auth.currentUser;
    String? selectedSubjectId;
    String? selectedSubjectName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.style_rounded,
                            color: FlashcardsTheme.brightOrange),
                        SizedBox(width: 8),
                        Text(
                          'Generate Flashcards',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: FlashcardsTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Subject Folder Selector Dropdown
                if (user != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('subjects')
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? [];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color:
                              FlashcardsTheme.pastelOrangeCard.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: FlashcardsTheme.orangeBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSubjectId,
                            isExpanded: true,
                            hint: const Text(
                                'Connect to Subject Folder (e.g. CS101)'),
                            items: docs.map((d) {
                              final name = d['name'] ?? 'Subject';
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  selectedSubjectId = val;
                                  final match =
                                      docs.firstWhere((d) => d.id == val);
                                  selectedSubjectName = match['name'];
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),

                // 2. Chapter & Focus Prompt Textbox
                TextField(
                  controller: _topicController,
                  maxLines: 3,
                  style: const TextStyle(
                      color: FlashcardsTheme.textDark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. "Give important points for chapter 1 of CS101" or "Focus on memory management definitions"…',
                    hintStyle: const TextStyle(
                        color: FlashcardsTheme.textMuted, fontSize: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                          color: FlashcardsTheme.brightOrange, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Bright Orange Action Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: FlashcardsTheme.orangeButtonGradient),
                    boxShadow: [
                      BoxShadow(
                        color: FlashcardsTheme.brightOrange.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _generateFlashcardsFromSubject(
                              subjectId: selectedSubjectId,
                              subjectName: selectedSubjectName,
                              userPrompt: _topicController.text.trim(),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Generate Cards with AI',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentCard = _flashcards.isNotEmpty
        ? _flashcards[_currentIndex]
        : {
            'question': 'No flashcards available',
            'answer': 'Add one or generate with AI',
            'subject': 'General'
          };

    return Scaffold(
      backgroundColor: FlashcardsTheme.pageBg,
      body: Stack(
        children: [
          // Ambient Pastel Orange Background Circles
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlashcardsTheme.pastelOrangeCard.withOpacity(0.4),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlashcardsTheme.orangeBorder.withOpacity(0.3),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),

                  // Quick Subject Generation Box
                  _buildSubjectQuickBar(),
                  const SizedBox(height: 16),

                  // Deck counter and Save-as-Image
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Card ${_currentIndex + 1} of ${_flashcards.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: FlashcardsTheme.copperDark,
                          fontSize: 13,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saveFlashcardAsImage,
                        icon: const Icon(Icons.download_rounded,
                            size: 16, color: FlashcardsTheme.copperAccent),
                        label: const Text(
                          'Save as Image',
                          style: TextStyle(
                            color: FlashcardsTheme.copperAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Interactive Pastel Orange Card ──
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showAnswer = !_showAnswer),
                      child: RepaintBoundary(
                        key: _cardBoundaryKey,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _showAnswer
                                  ? FlashcardsTheme.answerCardGradient
                                  : FlashcardsTheme.questionCardGradient,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: FlashcardsTheme.orangeBorder,
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FlashcardsTheme.brightOrange
                                    .withOpacity(0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Bar on Card
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: FlashcardsTheme.copperAccent
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      currentCard['subject'] ?? 'Concept',
                                      style: const TextStyle(
                                        color: FlashcardsTheme.copperDark,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _showAnswer ? 'ANSWER' : 'QUESTION',
                                    style: const TextStyle(
                                      color: FlashcardsTheme.copperDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),

                              // Card Center Text (Dark Navy for Maximum Contrast)
                              Center(
                                child: Text(
                                  _showAnswer
                                      ? currentCard['answer']!
                                      : currentCard['question']!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: FlashcardsTheme.textDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              // Bottom Tap Indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.touch_app_outlined,
                                    color: FlashcardsTheme.copperAccent
                                        .withOpacity(0.8),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showAnswer
                                        ? 'Tap to view question'
                                        : 'Tap to reveal answer',
                                    style: TextStyle(
                                      color: FlashcardsTheme.copperAccent
                                          .withOpacity(0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Navigation & Bright Orange Action Buttons ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 38,
                        onPressed: _currentIndex > 0
                            ? () => setState(() {
                                  _currentIndex--;
                                  _showAnswer = false;
                                })
                            : null,
                        icon: Icon(
                          Icons.arrow_circle_left_rounded,
                          color: _currentIndex > 0
                              ? FlashcardsTheme.brightOrange
                              : Colors.grey.shade300,
                        ),
                      ),
                      // Bright Orange Flip Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: FlashcardsTheme.orangeButtonGradient,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  FlashcardsTheme.brightOrange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _showAnswer = !_showAnswer),
                          icon: const Icon(Icons.flip_rounded,
                              color: Colors.white),
                          label: Text(
                            _showAnswer ? 'View Question' : 'Reveal Answer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 38,
                        onPressed: _currentIndex < _flashcards.length - 1
                            ? () => setState(() {
                                  _currentIndex++;
                                  _showAnswer = false;
                                })
                            : null,
                        icon: Icon(
                          Icons.arrow_circle_right_rounded,
                          color: _currentIndex < _flashcards.length - 1
                              ? FlashcardsTheme.brightOrange
                              : Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back,
              color: FlashcardsTheme.textDark, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        Column(
          children: const [
            Text(
              'VU Flashcards Hub',
              style: TextStyle(
                color: FlashcardsTheme.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Pastel Orange & Copper Theme',
              style: TextStyle(
                color: FlashcardsTheme.brightOrange,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded,
              color: FlashcardsTheme.brightOrange),
          tooltip: 'Custom Prompt Deck',
          onPressed: _openCreateSheet,
        ),
      ],
    );
  }

  // Quick Action Bar to fetch from Subjects Folder directly on screen
  Widget _buildSubjectQuickBar() {
    return GestureDetector(
      onTap: _openCreateSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FlashcardsTheme.pastelOrangeCard.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlashcardsTheme.orangeBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: FlashcardsTheme.orangeButtonGradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_shared_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Generate from Subject Folder (e.g. Chapter 1 of CS101)...',
                style: TextStyle(
                  color: FlashcardsTheme.copperDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: FlashcardsTheme.copperAccent),
          ],
        ),
      ),
    );
  }
}
