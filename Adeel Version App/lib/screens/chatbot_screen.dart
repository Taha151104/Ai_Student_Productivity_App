import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_session_model.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';

/// UC-19 Ask AI Chatbot — with persistent learner memory and Syllabus grounding.
///
/// Context flow (per message):
///   1. User sends message.
///   2. [_extractAndSaveMemories] — AI extracts facts → upserted to users/{uid}/memories/{key}.
///   3. [_loadUserSubjectContext] — reads syllabus files from users/{uid}/subjects or root subjects.
///   4. [_buildSystemPrompt]     — builds persona and learner profile.
///   5. [_aiService.askChatbot]  — responds with syllabus-grounded multi-turn context.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final _aiService = AiService();
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  // ── State ─────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];

  /// Conversation history in OpenAI/Gemini compatible format.
  final List<Map<String, String>> _history = [];

  /// Learner memories loaded from Firestore: { key → value }.
  Map<String, String> _memories = {};

  bool _isLoading = false;
  bool _showMemories = false;
  int _activeSubjectCount = 0;

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C3CF7);
  static const Color pageBg = Color(0xFFEEEBFD);
  static const Color fieldFill = Color(0xFFF0EDFE);
  static const Color textDark = Color(0xFF1A1040);
  static const Color textMuted = Color(0xFF5B5E7A);
  static const Color userBubble = Color(0xFF6C3CF7);
  static const Color botBubble = Color(0xFFFFFFFF);

  static const Map<String, String> _memoryLabels = {
    'name': '👤 Name',
    'education_level': '🎓 Education level',
    'institution': '🏫 Institution',
    'subject': '📚 Subject',
    'learning_style': '🧠 Learning style',
    'preferred_language': '🌐 Language',
    'study_goal': '🎯 Goal',
    'weakness': '⚠️ Weakness',
    'strength': '✅ Strength',
    'age': '🎂 Age',
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        sender: 'ai',
        text: 'Hello! I\'m your AI study tutor. 🎓\n\n'
            'I have direct access to your uploaded semester subjects, textbooks, and notes, '
            'and I\'ll remember your learning preferences to give syllabus-accurate answers.',
        timestamp: DateTime.now(),
      ),
    );
    _loadMemories();
    _countActiveSubjects();
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
          .get();
      if (mounted) {
        setState(() => _activeSubjectCount = snap.docs.length);
      }
    } catch (_) {}
  }

  // ── Memory Management ─────────────────────────────────────────────────────

  Future<void> _loadMemories() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final facts = await _firestoreService.loadMemories(uid);
      if (mounted) setState(() => _memories = facts);
    } catch (e) {
      debugPrint('Memory load error: $e');
    }
  }

  Future<void> _extractAndSaveMemories(String userMessage) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final extracted = await _aiService.extractMemoryFacts(userMessage);
      if (extracted.isEmpty) return;

      for (final entry in extracted.entries) {
        await _firestoreService.upsertMemory(uid, entry.key, entry.value);
        _memories[entry.key] = entry.value;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Memory extraction error: $e');
    }
  }

  Future<void> _deleteMemory(String key) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestoreService.deleteMemory(uid, key);
      setState(() => _memories.remove(key));
    } catch (e) {
      debugPrint('Memory delete error: $e');
    }
  }

  // ── Subject & Syllabus Knowledge Retrieval ────────────────────────────────

  Future<String> _loadUserSubjectContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return '';

    try {
      final buffer = StringBuffer();

      // 1. Check user-specific collection first
      var subjectsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .get();

      // 2. Fallback to root collection if user-specific is empty
      if (subjectsSnap.docs.isEmpty) {
        subjectsSnap = await _firestore
            .collection('subjects')
            .where('userId', isEqualTo: uid)
            .get();
      }

      if (subjectsSnap.docs.isEmpty) return '';

      for (final subjectDoc in subjectsSnap.docs) {
        final subjectName = subjectDoc['name'] ?? 'Course Subject';

        final filesSnap = await subjectDoc.reference
            .collection('files')
            .orderBy('uploadedAt', descending: true)
            .limit(10)
            .get();

        if (filesSnap.docs.isNotEmpty) {
          buffer.writeln('\n[SUBJECT FOLDER: $subjectName]');
          for (final fileDoc in filesSnap.docs) {
            final fileName = fileDoc['fileName'] ?? 'Document';
            final content =
                (fileDoc['extractedContent'] ?? fileDoc['preview'] ?? '')
                    .toString()
                    .trim();

            if (content.isNotEmpty) {
              // Cap at 3,500 characters per file to avoid Gemini context overload
              final safeText = content.length > 3500
                  ? '${content.substring(0, 3500)}...'
                  : content;
              buffer.writeln('--- File: $fileName ---');
              buffer.writeln(safeText);
              buffer.writeln('-----------------------\n');
            }
          }
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Error loading subject context: $e');
      return '';
    }
  }

  /// Builds the personalized system instructions for the AI model.
  String _buildSystemPrompt() {
    final buffer = StringBuffer();

    buffer.writeln(
      'You are an intelligent, academic AI study tutor for a university student productivity app. '
      'Your mission is to help students excel in their courses by explaining concepts clearly, '
      'answering syllabus-specific exam questions, solving problems step-by-step, and providing concise study strategies.',
    );

    if (_memories.isNotEmpty) {
      buffer.writeln('\n--- What you know about this student ---');
      for (final e in _memories.entries) {
        final label = _memoryLabels[e.key] ?? e.key;
        buffer.writeln('$label: ${e.value}');
      }
      buffer.writeln(
        '\nUse these learner facts to personalize every response. Do NOT recite '
        'these facts back to the student unless asked.',
      );
    }

    return buffer.toString();
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(
          ChatMessage(sender: 'user', text: text, timestamp: DateTime.now()));
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      // 1. Extract learner memories in background
      _extractAndSaveMemories(text);

      // 2. Fetch all syllabus files from student's folders
      final syllabusContext = await _loadUserSubjectContext();

      // 3. Construct prompt where syllabus text is directly available to Gemini
      String promptToSend = text;
      if (syllabusContext.trim().isNotEmpty) {
        promptToSend = '''
STUDENT'S UPLOADED COURSE MATERIALS & SYLLABUS FILES:
"""
$syllabusContext
"""

STUDENT'S QUESTION:
$text

INSTRUCTION: 
Answer the student's question accurately using their uploaded course materials and syllabus files above whenever relevant. If they ask for an outline, summary, or specific topics from their files (such as MC301), cite and extract them directly from the text provided above.
''';
      }

      final systemPrompt = _buildSystemPrompt();

      // 4. Send to AI Service with a 25-second safeguard timeout
      final reply = await _aiService
          .askChatbot(
        promptToSend,
        systemPrompt: systemPrompt,
        history: List.of(_history),
      )
          .timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          return "I took too long to read through all the handouts. Could you ask about a specific chapter or topic from your MC301 subject?";
        },
      );

      // Maintain conversational history
      _history.add({'role': 'user', 'content': text});
      _history.add({'role': 'assistant', 'content': reply});

      if (mounted) {
        setState(() => _messages.add(
            ChatMessage(sender: 'ai', text: reply, timestamp: DateTime.now())));
      }
    } catch (e) {
      debugPrint('Chatbot error: $e');
      if (mounted) {
        setState(() => _messages.add(ChatMessage(
              sender: 'ai',
              text:
                  'Could not read the syllabus files: $e\nPlease verify that your MC301 folder contains uploaded text or notes.',
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Memory drawer
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _showMemories
                  ? _buildMemoryDrawer()
                  : const SizedBox.shrink(),
            ),

            // Chat messages
            Expanded(child: _buildMessageList()),

            // Typing indicator
            if (_isLoading) _buildTypingIndicator(),

            // Input bar with active syllabus indicator
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: pageBg,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: textDark, size: 22),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFFA855F7), Color(0xFF6C3CF7)]),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Study Tutor',
                  style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
              if (_activeSubjectCount > 0)
                Text('$_activeSubjectCount subjects linked',
                    style: const TextStyle(
                        color: primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: 'Learner memories',
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.psychology_rounded,
                    color: _showMemories ? primary : textMuted,
                    size: 26,
                  ),
                  onPressed: () =>
                      setState(() => _showMemories = !_showMemories),
                ),
                if (_memories.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: primary),
                      child: Center(
                        child: Text(
                          _memories.length.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Memory Drawer ─────────────────────────────────────────────────────────

  Widget _buildMemoryDrawer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: primary, size: 18),
              const SizedBox(width: 8),
              const Text('What I know about you',
                  style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
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
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      padding: EdgeInsets.zero),
                  child:
                      const Text('Clear all', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_memories.isEmpty)
            const Text(
              'No personalized memories yet. Chat with me and I\'ll learn your study goals automatically.',
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _memories.entries.map((e) {
                final label = _memoryLabels[e.key] ?? e.key;
                return Chip(
                  backgroundColor: fieldFill,
                  side: BorderSide(color: primary.withValues(alpha: 0.2)),
                  label: Text('$label: ${e.value}',
                      style: const TextStyle(color: textDark, fontSize: 12)),
                  deleteIcon: const Icon(Icons.close_rounded,
                      size: 14, color: textMuted),
                  onDeleted: () => _deleteMemory(e.key),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── Message List ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isUser = msg.sender == 'user';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isUser ? userBubble : botBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isUser ? primary : Colors.black).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                  color: isUser ? Colors.white : textDark,
                  fontSize: 14,
                  height: 1.5),
            ),
          ),
        );
      },
    );
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(children: [
        _dot(0),
        _dot(150),
        _dot(300),
        const SizedBox(width: 10),
        const Text('Consulting syllabus & formulating answer…',
            style: TextStyle(color: textMuted, fontSize: 12.5)),
      ]),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary.withValues(alpha: 0.3 + 0.7 * v),
        ),
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: fieldFill,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: const TextStyle(color: textDark, fontSize: 15),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Ask about any of your subjects or notes…',
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!_isLoading) _sendMessage();
                },
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF6C3CF7), Color(0xFF06B6D4)]),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
