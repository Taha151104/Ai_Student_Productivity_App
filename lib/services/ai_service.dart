// ============================================================================
// COMPLETE, BACKWARDS-COMPATIBLE ai_service.dart
// Supports Chatbot, Memory, Summarizer, Flashcards, Vision OCR & Quiz Generation
// ============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AiService {
  // Read keys from config/dev-keys.json or --dart-define
  static const String _hfApiKey =
      String.fromEnvironment('HUGGINGFACE_API_KEY', defaultValue: '');
  static const String _geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');

  static const String _textModel = 'meta-llama/Llama-3.1-8B-Instruct:fastest';
  static const String _visionModel =
      'meta-llama/Llama-3.2-11B-Vision-Instruct:cerebras';
  static const String _apiUrl =
      'https://router.huggingface.co/v1/chat/completions';

  // ── 1. Quiz Generator (Compatible with all screens) ───────────────────────

  /// Supports both legacy single-argument calls: generateQuizJson(text)
  /// AND new customized calls: generateQuizJson(text, questionCount: 15, userFocusInstruction: "first lecture")
  Future<String> generateQuizJson(
    String noteText, {
    int questionCount = 10,
    String? userFocusInstruction,
    String? topicHint,
  }) async {
    // 1. Token Budget Optimization: smart slice to prevent hitting free token limits
    final filteredMaterial = _optimizeTextForTokenBudget(
      fullText: noteText,
      userFocus: userFocusInstruction ?? '',
    );

    final systemInstruction =
        'You are a senior university examination board author. Generate exactly $questionCount multiple-choice questions (MCQs) '
        'based strictly on the academic content of the study material. '
        'CRITICAL RULES:\n'
        '1. If a specific scope is requested (e.g. "first lecture", "Chapter 2"), strictly generate questions from that section only.\n'
        '2. NEVER ask meta-questions about the file format (e.g. do NOT ask "Which PDF format are the handouts?").\n'
        '3. Each question must have EXACTLY 4 distinct options and 1 unambiguously correct answer matching one of the options.\n'
        '4. Respond ONLY with a valid JSON array of objects: [{"question": "...", "options": ["...","...","...","..."], "correctAnswer": "..."}]. '
        'No preamble or Markdown code fences.';

    final userPrompt = '''
Study Material:
$filteredMaterial

${(userFocusInstruction != null && userFocusInstruction.trim().isNotEmpty) ? "STUDENT SPECIFIC FOCUS / SCOPE:\n$userFocusInstruction\n" : ""}
Generate exactly $questionCount exam MCQs adhering strictly to the material above.
Return ONLY a valid JSON array.
''';

    // Try Gemini if key is provided
    if (_geminiApiKey.isNotEmpty) {
      try {
        return await _callGemini(systemInstruction, userPrompt, questionCount);
      } catch (_) {}
    }

    // Try OpenRouter if key is provided
    if (_openRouterApiKey.isNotEmpty) {
      try {
        return await _callOpenRouter(
            systemInstruction, userPrompt, questionCount);
      } catch (_) {}
    }

    // Fallback to Hugging Face
    final messages = [
      {'role': 'system', 'content': systemInstruction},
      {'role': 'user', 'content': userPrompt},
    ];

    final raw = await _callMessages(
      messages,
      maxTokens: (questionCount * 140).clamp(1200, 4096),
      temperature: 0.2,
    );

    return _cleanJsonResponse(raw);
  }

  // ── 2. Chatbot Screen Support ─────────────────────────────────────────────

  Future<String> askChatbot(
    String userMessage, {
    String? systemPrompt,
    List<Map<String, String>>? history,
  }) async {
    final messages = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }

    if (history != null) {
      final recent =
          history.length > 10 ? history.sublist(history.length - 10) : history;
      messages.addAll(recent);
    }

    messages.add({'role': 'user', 'content': userMessage});

    return _callMessages(messages);
  }

  // ── 3. Memory Extraction Support ──────────────────────────────────────────

  Future<Map<String, String>> extractMemoryFacts(String userMessage) async {
    const schema = '{'
        '"name": "student\'s name if mentioned",'
        '"education_level": "e.g. BSc, A-levels, matric, undergraduate",'
        '"institution": "school or university name",'
        '"subject": "current study subject or course",'
        '"learning_style": "e.g. visual, reading, practice-based",'
        '"preferred_language": "language they prefer to study in",'
        '"study_goal": "what they want to achieve",'
        '"weakness": "topic or subject they struggle with",'
        '"strength": "topic or subject they are good at",'
        '"age": "age if mentioned"'
        '}';

    final prompt =
        'Analyse the following student message and extract any personal or '
        'academic facts that would help personalise future responses. '
        'Return ONLY a valid JSON object using these exact keys (omit any key '
        'where no information is present): $schema\n\n'
        'Student message: "$userMessage"\n\n'
        'JSON (return {} if nothing found):';

    try {
      final raw = await _callMessages([
        {'role': 'user', 'content': prompt}
      ], maxTokens: 256, temperature: 0.1);

      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return {};

      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! Map) return {};

      return {
        for (final e in decoded.entries)
          if (e.value is String && (e.value as String).trim().isNotEmpty)
            e.key.toString(): (e.value as String).trim(),
      };
    } catch (_) {
      return {};
    }
  }

  // ── 4. AI Summary Screen Support ──────────────────────────────────────────

  Future<String> generateSummary(String noteText,
      {String format = 'short'}) async {
    final prompt = format == 'short'
        ? 'Summarize the following study notes in 3-4 concise sentences:\n\n$noteText'
        : 'Provide a detailed, well-structured summary of the following study notes:\n\n$noteText';
    return _callText(prompt);
  }

  // ── 5. Flashcards Screen Support ──────────────────────────────────────────

  Future<String> generateFlashcardsJson(String noteText) async {
    final prompt =
        'Generate 8 flashcards (front/back) from the following study notes. '
        'Respond ONLY with valid JSON: [{"front": "...", "back": "..."}]\n\n$noteText';
    final raw = await _callText(prompt);
    return _cleanJsonResponse(raw);
  }

  // ── 6. Notes Upload & Vision OCR Support ──────────────────────────────────

  Future<String> extractTextFromImageBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    _assertKey();
    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Image';

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': dataUri}
              },
              {
                'type': 'text',
                'text': 'Extract and return ALL text visible in this image '
                    'exactly as it appears. Preserve formatting and line '
                    'breaks. Output raw extracted text only.',
              },
            ],
          }
        ],
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OCR API error: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Internal Helpers & Free Tier Failovers ────────────────────────────────

  String _optimizeTextForTokenBudget({
    required String fullText,
    required String userFocus,
  }) {
    if (fullText.length <= 12000) return fullText;

    final lowerFocus = userFocus.toLowerCase();
    final lectureMatch = RegExp(
            r'(?:lecture|lesson|chapter|module|topic)\s*([0-9ivx]+)',
            caseSensitive: false)
        .firstMatch(lowerFocus);

    if (lectureMatch != null) {
      final target = lectureMatch.group(0)!;
      final index = fullText.toLowerCase().indexOf(target);
      if (index != -1) {
        final end = (index + 10000).clamp(0, fullText.length);
        return fullText.substring(index, end);
      }
    }

    return fullText.substring(0, 12000);
  }

  Future<String> _callGemini(String system, String prompt, int count) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': '$system\n\n$prompt'}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
          'maxOutputTokens': (count * 150).clamp(1000, 4000),
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini Error ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    return _cleanJsonResponse(text);
  }

  Future<String> _callOpenRouter(
      String system, String prompt, int count) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_openRouterApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-3.1-8b-instruct:free',
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.2,
        'max_tokens': (count * 150).clamp(1000, 3000),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenRouter Error ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return _cleanJsonResponse(
        data['choices'][0]['message']['content'] as String);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_hfApiKey',
        'Content-Type': 'application/json',
      };

  void _assertKey() {
    if (_hfApiKey.isEmpty &&
        _geminiApiKey.isEmpty &&
        _openRouterApiKey.isEmpty) {
      throw Exception(
          'No API key provided. Run with --dart-define-from-file=config/dev-keys.json');
    }
  }

  Future<String> _callText(String prompt) => _callMessages([
        {'role': 'user', 'content': prompt}
      ]);

  Future<String> _callMessages(
    List<Map<String, dynamic>> messages, {
    int maxTokens = 1024,
    double temperature = 0.5,
  }) async {
    _assertKey();
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _textModel,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('AI API error: ${response.statusCode} ${response.body}');
    }
    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    if (content == null) {
      throw Exception('Empty content returned from AI provider.');
    }
    return content as String;
  }

  String _cleanJsonResponse(String raw) {
    String cleaned = raw.trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'^\s*```(?:json)?', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    final sBracket = cleaned.indexOf('[');
    final eBracket = cleaned.lastIndexOf(']');
    if (sBracket != -1 && eBracket != -1 && eBracket > sBracket) {
      return cleaned.substring(sBracket, eBracket + 1);
    }

    final sBrace = cleaned.indexOf('{');
    final eBrace = cleaned.lastIndexOf('}');
    if (sBrace != -1 && eBrace != -1 && eBrace > sBrace) {
      return cleaned.substring(sBrace, eBrace + 1);
    }

    return cleaned;
  }
}
