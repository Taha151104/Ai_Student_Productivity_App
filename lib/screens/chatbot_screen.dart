import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';

class _PdfPageAttachment {
  final Uint8List imageBytes;
  final String fileName;
  final int pageNumber;

  const _PdfPageAttachment({
    required this.imageBytes,
    required this.fileName,
    required this.pageNumber,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎨 EDIT CHATBOT THEME & COLORS RIGHT HERE:
// ─────────────────────────────────────────────────────────────────────────────
class ChatbotTheme {
  static const Color pageBg = Colors.white; // White Canvas
  static const Color royalPurple = Color(0xFF7E22CE); // Royal Purple Primary
  static const Color purpleAccent =
      Color(0xFFA855F7); // Vibrant Electric Purple
  static const Color pastelLavender = Color(0xFFF3E8FF); // Soft Pastel Lavender
  static const Color lavenderBorder = Color(0xFFD8B4FE); // Lavender Outline
  static const Color userBubble = Color(0xFFE9D5FF); // User: Lavender Box
  static const Color userText = Color(0xFF0F172A); // User: Black Text
  static const Color botBubble = Colors.white; // AI: White Dialogue Box
  static const Color botText = Color(0xFF0F172A); // AI: Black Text
  static const Color textDark = Color(0xFF1E1348);
  static const Color textMuted = Color(0xFF64748B);

  // Golden Theme Send & Confirmation Button (Contrasts with Purple)
  static const Color goldenPrimary = Color(0xFFD97706);
  static const List<Color> goldenButtonGradient = [
    Color(0xFFFBBF24),
    Color(0xFFD97706),
  ];
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _aiService = AiService();
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _history = [];
  Map<String, String> _memories = {};

  bool _isLoading = false;
  bool _showMemories = false;
  bool _languageReady = false;
  int _activeSubjectCount = 0;
  String _preferredLanguage = 'English';

  static const String _languagePreferenceKey = 'chat_preferred_language';

  static const Map<String, String> _memoryLabels = {
    'name': '👤 Name',
    'education_level': '🎓 Education',
    'institution': '🏫 Institution',
    'subject': '📚 Subject',
    'learning_style': '🧠 Style',
    'preferred_language': '🌐 Language',
    'study_goal': '🎯 Goal',
    'weakness': '⚠️ Weakness',
    'strength': '✅ Strength',
  };

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        sender: 'ai',
        text: 'Hi! I\'m your AI study assistant. 😊\n\n'
            'What would you like to talk about?',
        timestamp: DateTime.now(),
      ),
    );
    _loadLanguagePreference();
    _loadMemories();
    _countActiveSubjects();
  }

  Future<void> _loadLanguagePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage = preferences.getString(_languagePreferenceKey);
    if (savedLanguage != null) {
      if (mounted) {
        setState(() {
          _preferredLanguage = savedLanguage;
          _languageReady = true;
        });
      }
      return;
    }

    if (!mounted) return;
    final language = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose your chat language'),
        content: const Text(
          'I’ll use your choice consistently for conversations. Study answers can keep key technical terms in English.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'English'),
            child: const Text('English'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'Urdu'),
            child: const Text('اردو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'Roman Urdu'),
            child: const Text('Roman Urdu'),
          ),
        ],
      ),
    );
    final selectedLanguage = language ?? 'English';
    await preferences.setString(_languagePreferenceKey, selectedLanguage);
    if (mounted) {
      setState(() {
        _preferredLanguage = selectedLanguage;
        _languageReady = true;
        _messages[0] = ChatMessage(
          sender: 'ai',
          text:
              'Hi! I’m your AI study assistant. I’ll reply in $selectedLanguage. You can ask me to switch languages whenever you like.',
          timestamp: DateTime.now(),
        );
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _countActiveSubjects() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .get()
          .timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() => _activeSubjectCount = snap.docs.length);
      }
    } catch (_) {}
  }

  Future<void> _loadMemories() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final facts = await _firestoreService
          .loadMemories(uid)
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _memories = facts);
    } catch (_) {}
  }

  Future<void> _extractAndSaveMemories(String userMessage) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final extracted = await _aiService
          .extractMemoryFacts(userMessage)
          .timeout(const Duration(seconds: 8));
      if (extracted.isEmpty) return;

      for (final entry in extracted.entries) {
        await _firestoreService
            .upsertMemory(uid, entry.key, entry.value)
            .timeout(const Duration(seconds: 4));
        _memories[entry.key] = entry.value;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _deleteMemory(String key) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestoreService.deleteMemory(uid, key);
      setState(() => _memories.remove(key));
    } catch (_) {}
  }

  // ── Load Grounding Context from User's Subject Folders ────────────────────
  Future<String> _loadUserSubjectContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return '';

    try {
      final buffer = StringBuffer();
      final subjectsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .limit(6)
          .get()
          .timeout(const Duration(seconds: 5));

      if (subjectsSnap.docs.isEmpty) return '';

      for (final subjectDoc in subjectsSnap.docs) {
        final subjectName = subjectDoc['name'] ?? 'Subject Folder';
        final filesSnap = await subjectDoc.reference
            .collection('files')
            .orderBy('uploadedAt', descending: true)
            .limit(3)
            .get()
            .timeout(const Duration(seconds: 4));

        if (filesSnap.docs.isNotEmpty) {
          buffer.writeln('\n[COURSE REPOSITORY: $subjectName]');
          for (final fileDoc in filesSnap.docs) {
            final fileName = fileDoc['fileName'] ?? 'Handout';
            final content =
                (fileDoc['extractedContent'] ?? fileDoc['preview'] ?? '')
                    .toString()
                    .trim();

            if (content.isNotEmpty) {
              final snippet = content.length > 1800
                  ? '${content.substring(0, 1800)}...'
                  : content;
              buffer.writeln('Document ($fileName): $snippet');
            }
          }
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  Future<_PdfPageAttachment?> _loadPdfPageForQuestion(
    String question,
    int pageNumber,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final subjects = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get()
        .timeout(const Duration(seconds: 8));

    final matchingFiles = <Map<String, dynamic>>[];
    final questionLower = question.toLowerCase();
    for (final subject in subjects.docs) {
      final files = await subject.reference
          .collection('files')
          .where('fileType', isEqualTo: 'pdf')
          .get()
          .timeout(const Duration(seconds: 8));
      for (final file in files.docs) {
        final data = file.data();
        final path = (data['originalStoragePath'] ?? '').toString();
        final pageText = (data['extractedContent'] ?? '').toString();
        final pageCount = data['pageCount'];
        final hasPage = pageCount is int
            ? pageCount >= pageNumber
            : pageText.contains('[Page $pageNumber]');
        if (path.isEmpty || !hasPage) continue;
        matchingFiles.add({...data, 'originalStoragePath': path});
      }
    }

    if (matchingFiles.isEmpty) return null;
    final namedMatches = matchingFiles.where((file) {
      final name = (file['fileName'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll('.pdf', '');
      return name.isNotEmpty && questionLower.contains(name);
    }).toList();
    if (namedMatches.isEmpty && matchingFiles.length > 1) return null;
    final file =
        namedMatches.isEmpty ? matchingFiles.first : namedMatches.first;
    final bytes = await FirebaseStorage.instance
        .ref(file['originalStoragePath'] as String)
        .getData(20 * 1024 * 1024);
    if (bytes == null) return null;

    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(
      bytes,
      sourceName: (file['fileName'] ?? 'handout.pdf').toString(),
    );
    try {
      if (pageNumber < 1 || pageNumber > document.pages.length) return null;
      final page = document.pages[pageNumber - 1];
      final pageImage = await page.render(fullWidth: 1400, fullHeight: 1800);
      if (pageImage == null) return null;
      try {
        final image = await pageImage.createImage();
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) return null;
          return _PdfPageAttachment(
            imageBytes: png.buffer.asUint8List(),
            fileName: (file['fileName'] ?? 'handout.pdf').toString(),
            pageNumber: pageNumber,
          );
        } finally {
          image.dispose();
        }
      } finally {
        pageImage.dispose();
      }
    } finally {
      document.dispose();
    }
  }

  // ── Multilingual & Academic System Prompt ──────────────────────────────────
  String _buildSystemPrompt() {
    final buffer = StringBuffer();

    buffer.writeln(
      'You are a friendly, approachable AI study assistant who can also chat about other topics.\n\n'
      'CONVERSATION STYLE:\n'
      '1. Be warm, relaxed, and respectful. Follow the user\'s lead and respond naturally.\n'
      '2. Do not assume the user is struggling, has a problem, or wants study advice or a plan.\n'
      '3. For a simple greeting, greet them back briefly. At most, add one gentle, optional invitation to continue; do not ask several questions or ask about their plans or personal life unless they bring it up.\n'
      '4. Avoid unsolicited advice, pressure, over-familiarity, and repeatedly offering help. Answer what they actually asked, and let them choose what to discuss.\n'
      '5. Do not mention remembered personal details unless they are directly relevant to the user\'s request.\n\n'
      'MULTILINGUAL & NUMERICAL ABILITY:\n'
      '1. Fluent in English, Urdu (اردو), and Roman Urdu (e.g., "Mujhe ye concept asan alfaz mein samjha dein", "Formula explain karo").\n'
      '2. Understand numbers, equations, mathematical symbols, and calculations accurately.\n'
      '3. Use $_preferredLanguage consistently, even when the user mixes languages or uses short phrases. Do not randomly switch languages or infer a new preference from a single message.\n'
      '4. For study topics, keep important technical terms in English and explain them in $_preferredLanguage. If the user explicitly asks to switch languages, honor that request.\n\n'
      'SCOPE & KNOWLEDGE BASE:\n'
      '1. When relevant to a course-related question, use the student\'s uploaded subject materials and lecture files to ground your answer. Do not bring up those materials unless they are relevant to the request.\n'
      '2. You are ALSO knowledgeable beyond the syllabus. If the student asks general, non-study questions (everyday advice, tech, history, logic, productivity, casual chat), answer accurately, intelligently, and helpfully without refusing.',
    );

    if (_memories.isNotEmpty) {
      buffer.writeln('\nLearner profile:');
      for (final e in _memories.entries) {
        if (e.key == 'preferred_language') continue;
        buffer.writeln('- ${e.key}: ${e.value}');
      }
    }

    return buffer.toString();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;
    if (!_languageReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose your chat language first.')),
      );
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage(sender: 'user', text: text, timestamp: DateTime.now()),
      );
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      _extractAndSaveMemories(text);
      final syllabusContext = await _loadUserSubjectContext();
      Uint8List? diagramPageImage;
      int? requestedPdfPage;
      final asksAboutVisual = RegExp(
        r'\b(diagram|figure|chart|graph|illustration)\b',
        caseSensitive: false,
      ).hasMatch(text);
      if (asksAboutVisual) {
        final pageMatches = RegExp(
          r'\bpage(?:\s+number)?\s+(\d+)\b|\bp\.?\s*(\d+)\b',
          caseSensitive: false,
        ).firstMatch(text);
        final pageNumber =
            int.tryParse(pageMatches?.group(1) ?? pageMatches?.group(2) ?? '');
        if (pageNumber == null) {
          const reply =
              'Please mention the PDF page number so I can inspect the correct diagram.';
          if (mounted) {
            setState(() => _messages.add(
                  ChatMessage(
                      sender: 'ai', text: reply, timestamp: DateTime.now()),
                ));
          }
          return;
        }
        requestedPdfPage = pageNumber;
        final page = await _loadPdfPageForQuestion(text, pageNumber);
        if (page == null) {
          final reply =
              'I couldn’t find an accessible uploaded PDF page $pageNumber. Upload the PDF to a subject folder and include the PDF filename if that folder has multiple handouts.';
          if (mounted) {
            setState(() => _messages.add(
                  ChatMessage(
                      sender: 'ai', text: reply, timestamp: DateTime.now()),
                ));
          }
          return;
        }
        diagramPageImage = page.imageBytes;
      }

      String promptToSend = text;
      if (syllabusContext.trim().isNotEmpty) {
        promptToSend = '''
STUDENT'S UPLOADED SUBJECT FILES & HANDOUTS:
"""
$syllabusContext
"""

STUDENT'S QUERY:
$text

INSTRUCTION: If this query references course concepts or handouts from above, answer accurately using their syllabus files. If it is a general or non-study query, answer comprehensively with your broader knowledge.
''';
      }
      if (diagramPageImage != null) {
        promptToSend =
            'The attached image is page $requestedPdfPage of the uploaded PDF. Explain the visible diagram using the image and the syllabus text where relevant. Identify the source page in your answer.\n\n$text\n\n$syllabusContext';
      }

      final systemPrompt = _buildSystemPrompt();

      final reply = await _aiService
          .askChatbot(
            promptToSend,
            systemPrompt: systemPrompt,
            history: List.of(_history),
            imageBytes: diagramPageImage,
          )
          .timeout(
            const Duration(seconds: 22),
            onTimeout: () =>
                'Connection took a bit longer than expected. Please check your network and try again!',
          );

      _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': reply});
      if (_history.length > 16) _history.removeRange(0, 2);

      if (mounted) {
        setState(() => _messages.add(
              ChatMessage(sender: 'ai', text: reply, timestamp: DateTime.now()),
            ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(ChatMessage(
              sender: 'ai',
              text:
                  'Unable to reach the assistant. Please check your data connection.',
              timestamp: DateTime.now(),
            )));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatbotTheme.pageBg,
      body: Stack(
        children: [
          // Ambient Pastel Purple Designs
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ChatbotTheme.pastelLavender.withOpacity(0.55),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ChatbotTheme.purpleAccent.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ChatbotTheme.pastelLavender.withOpacity(0.4),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                // Memory Drawer
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _showMemories
                      ? _buildMemoryDrawer()
                      : const SizedBox.shrink(),
                ),
                // Messages List
                Expanded(child: _buildMessageList()),
                // Typing Indicator
                if (_isLoading) _buildTypingIndicator(),
                // Input Bar with Golden Send Button
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: ChatbotTheme.textDark, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [ChatbotTheme.purpleAccent, ChatbotTheme.royalPurple],
              ),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Study Tutor',
                  style: TextStyle(
                    color: ChatbotTheme.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                  ),
                ),
                Text(
                  _activeSubjectCount > 0
                      ? '$_activeSubjectCount subjects connected • EN / UR / رومن'
                      : 'Multilingual Study Assistant',
                  style: const TextStyle(
                    color: ChatbotTheme.royalPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.psychology_rounded,
              color: _showMemories
                  ? ChatbotTheme.royalPurple
                  : ChatbotTheme.textMuted,
              size: 26,
            ),
            tooltip: 'Learner Memory',
            onPressed: () => setState(() => _showMemories = !_showMemories),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryDrawer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatbotTheme.lavenderBorder),
        boxShadow: [
          BoxShadow(
            color: ChatbotTheme.royalPurple.withOpacity(0.08),
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
              const Icon(Icons.psychology_rounded,
                  color: ChatbotTheme.royalPurple, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Personalized Study Profile',
                style: TextStyle(
                  color: ChatbotTheme.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const Spacer(),
              if (_memories.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final uid = _auth.currentUser?.uid;
                    if (uid == null) return;
                    for (final key in List.of(_memories.keys)) {
                      await _firestoreService.deleteMemory(uid, key);
                    }
                    setState(() => _memories.clear());
                  },
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_memories.isEmpty)
            const Text(
              'No learned preferences yet. Chat naturally and I will personalize your answers.',
              style: TextStyle(color: ChatbotTheme.textMuted, fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _memories.entries.map((e) {
                final label = _memoryLabels[e.key] ?? e.key;
                return Chip(
                  backgroundColor: ChatbotTheme.pastelLavender,
                  side: const BorderSide(color: ChatbotTheme.lavenderBorder),
                  label: Text(
                    '$label: ${e.value}',
                    style: const TextStyle(
                        color: ChatbotTheme.textDark, fontSize: 11.5),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded,
                      size: 14, color: ChatbotTheme.textMuted),
                  onDeleted: () => _deleteMemory(e.key),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Dialogue Boxes: White for AI, Lavender for User ────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isUser = msg.sender == 'user';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: BoxDecoration(
              // User: Lavender, AI: White
              color: isUser ? ChatbotTheme.userBubble : ChatbotTheme.botBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: Border.all(
                color: isUser
                    ? ChatbotTheme.lavenderBorder
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isUser
                      ? ChatbotTheme.royalPurple.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SelectableText(
              msg.text,
              style: TextStyle(
                // Black text for both
                color: isUser ? ChatbotTheme.userText : ChatbotTheme.botText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              color: ChatbotTheme.royalPurple,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Consulting syllabus notes & formulating response…',
            style: TextStyle(
              color: ChatbotTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Bar with Golden Send Button ──────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: ChatbotTheme.pastelLavender.withOpacity(0.4),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ChatbotTheme.lavenderBorder, width: 1.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: const TextStyle(
                    color: ChatbotTheme.textDark, fontSize: 14.5),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Ask in English, Urdu, or Roman Urdu…',
                  hintStyle:
                      TextStyle(color: ChatbotTheme.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) {
                  if (!_isLoading) _sendMessage();
                },
              ),
            ),
            const SizedBox(width: 8),
            // Golden Contrast Send Button
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: ChatbotTheme.goldenButtonGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ChatbotTheme.goldenPrimary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
