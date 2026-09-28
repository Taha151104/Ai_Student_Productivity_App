import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import '../services/ai_service.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _aiService = AiService();
  final _topicController = TextEditingController();
  final GlobalKey _cardBoundaryKey = GlobalKey();

  List<Map<String, String>> _flashcards = [
    {
      'question': 'What is Object-Oriented Programming (OOP)?',
      'answer':
          'A programming paradigm based on the concept of "objects", which contain data (attributes) and code (methods). Core pillars: Encapsulation, Inheritance, Polymorphism, and Abstraction.',
      'subject': 'Computer Science',
    },
    {
      'question': 'Explain the difference between a Stack and a Queue.',
      'answer':
          'A Stack follows LIFO (Last-In, First-Out), whereas a Queue follows FIFO (First-In, First-Out).',
      'subject': 'Data Structures',
    },
    {
      'question': 'What is Normalization in Relational Databases?',
      'answer':
          'The process of organizing data to reduce redundancy and improve data integrity, commonly up to 3NF or BCNF.',
      'subject': 'Database Systems',
    },
  ];

  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = false;

  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFF8F7FF);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF6E6B80);

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  // ── AI Generation ─────────────────────────────────────────────────────────

  Future<void> _generateFlashcards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prompt = '''
Generate 6 exam-oriented flashcards for the topic or notes: "$topic".
Format strictly as a valid JSON array of objects:
[
  {"question": "Core concept question", "answer": "Clear concise answer", "subject": "Short subject tag"}
]
''';

      final res = await _aiService.generateQuizJson(prompt);
      final list = _extractJsonList(res);

      if (!mounted) return;
      setState(() {
        _flashcards = list.map((item) {
          final m = item as Map<String, dynamic>;
          return {
            'question': m['question']?.toString() ?? '',
            'answer': m['answer']?.toString() ?? '',
            'subject': m['subject']?.toString() ?? 'Exam Prep',
          };
        }).toList();
        _currentIndex = 0;
        _showAnswer = false;
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _extractJsonList(String raw) {
    final s = raw.indexOf('[');
    final e = raw.lastIndexOf(']');
    if (s != -1 && e != -1 && e > s) {
      return jsonDecode(raw.substring(s, e + 1)) as List;
    }
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['flashcards'] is List) {
      return decoded['flashcards'] as List;
    }
    throw const FormatException('Unexpected flashcard JSON format');
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Flashcard image saved & ready to share!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            const Text(
              'Generate Smart Flashcards',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter topic, chapter title, or paste lecture notes…',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateFlashcards,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Generate Cards with AI'),
            ),
          ],
        ),
      ),
    );
  }

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
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'VU Flashcards',
          style: TextStyle(
              color: textDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined, color: primary),
            tooltip: 'Save Flashcard as Image',
            onPressed: _saveFlashcardAsImage,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: primary),
            tooltip: 'Generate New Deck',
            onPressed: _openCreateSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Deck counter and Save-as-Image action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Card ${_currentIndex + 1} of ${_flashcards.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: textMuted),
                  ),
                  TextButton.icon(
                    onPressed: _saveFlashcardAsImage,
                    icon: const Icon(Icons.save_alt, size: 16, color: primary),
                    label: const Text('Save as Image',
                        style: TextStyle(color: primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive Flashcard with Image capture boundary
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showAnswer = !_showAnswer),
                  child: RepaintBoundary(
                    key: _cardBoundaryKey,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _showAnswer
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF047857)
                                ]
                              : [
                                  const Color(0xFF6366F1),
                                  const Color(0xFF4F46E5)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: (_showAnswer ? Colors.green : primary)
                                .withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  currentCard['subject'] ?? 'Concept',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _showAnswer ? 'ANSWER' : 'QUESTION',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          Center(
                            child: Text(
                              _showAnswer
                                  ? currentCard['answer']!
                                  : currentCard['question']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app_outlined,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 18),
                              const SizedBox(width: 6),
                              Text(
                                _showAnswer
                                    ? 'Tap to view question'
                                    : 'Tap to reveal answer',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Navigation controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: 36,
                    onPressed: _currentIndex > 0
                        ? () => setState(() {
                              _currentIndex--;
                              _showAnswer = false;
                            })
                        : null,
                    icon: Icon(
                      Icons.arrow_circle_left_rounded,
                      color: _currentIndex > 0 ? primary : Colors.grey.shade400,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showAnswer = !_showAnswer),
                    icon: const Icon(Icons.flip_rounded),
                    label:
                        Text(_showAnswer ? 'View Question' : 'Reveal Answer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  IconButton(
                    iconSize: 36,
                    onPressed: _currentIndex < _flashcards.length - 1
                        ? () => setState(() {
                              _currentIndex++;
                              _showAnswer = false;
                            })
                        : null,
                    icon: Icon(
                      Icons.arrow_circle_right_rounded,
                      color: _currentIndex < _flashcards.length - 1
                          ? primary
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
