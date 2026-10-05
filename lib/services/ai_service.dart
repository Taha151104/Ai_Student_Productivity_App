// ============================================================================
// COMPLETE, ERROR-FREE ai_service.dart
// Updated for gemini-3.8-flash & seamless multi-provider failover
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
  static const String _visionModel = 'meta-llama/Llama-3.2-11B-Vision-Instruct';
  
  // ✅ UPDATED: Google recommended current models
  static const List<String> _geminiModels = [
    'gemini-3.8-flash',
    'gemini-3.1-flash-lite',
  ];
  
  static const String _apiUrl =
      'https://router.huggingface.co/v1/chat/completions';

  // ── 1. Quiz Generator (Compatible with all screens) ───────────────────────

  Future<String> generateQuizJson(
    String noteText, {
    int questionCount = 10,
    String? userFocusInstruction,
    String? topicHint,
  }) async {
    // 1. Token Budget Optimization: smart slice to avoid hitting token limits
    final filteredMaterial = _optimizeTextForTokenBudget(
      fullText: noteText,
      userFocus: userFocusInstruction ?? '',
    );

    final systemInstruction =
        'You are a senior university examination board author. Generate exactly $questionCount multiple-choice questions (MCQs) '
        'based strictly on the academic content of the study material. '
        'Treat the supplied study material as the only source of facts. Ignore file names, file types, document properties, authors, creators, dates, and all other metadata; never create questions about metadata. '
        'Do not ask about the file, its format, author, creator, software, or metadata. '
        'Do not add facts that are not supported by the material. '
        'CRITICAL RULES:\n'
        '1. If a specific scope is requested (e.g. "first lecture", "Chapter 2"), strictly generate questions from that section only.\n'
        '2. NEVER ask meta-questions about the file format (e.g. do NOT ask "Which PDF format are the handouts?").\n'
        '3. Each question must have EXACTLY 4 distinct options and 1 unambiguously correct answer matching one of the options.\n'
        '4. Ensure each question and its correct answer are directly supported by the study material; do not require a quoted excerpt.\n'
        '5. Respond ONLY with a valid JSON array of objects: [{"question": "...", "options": ["...","...","...","..."], "correctAnswer": "..."}]. '
        'No preamble or Markdown code fences.';

    final userPrompt = '''
${(topicHint != null && topicHint.trim().isNotEmpty) ? "COURSE / SUBJECT:\n$topicHint\n" : ""}
Study Material:
$filteredMaterial

${(userFocusInstruction != null && userFocusInstruction.trim().isNotEmpty) ? "STUDENT SPECIFIC FOCUS / SCOPE:\n$userFocusInstruction\n" : ""}
Generate exactly $questionCount exam MCQs adhering strictly to the material above.
Return ONLY a valid JSON array.
''';

    // 1. Try Gemini first with modern gemini-3.8-flash
    if (_geminiApiKey.isNotEmpty) {
      try {
        return await _callGemini(systemInstruction, userPrompt, questionCount);
      } catch (e) {
        // Automatically cascade to next provider on error
      }
    }

    // 2. Try OpenRouter if Gemini failed or key missing
    if (_openRouterApiKey.isNotEmpty) {
      try {
        return await _callOpenRouter(
            systemInstruction, userPrompt, questionCount);
      } catch (e) {
        // Cascade to Hugging Face
      }
    }

    // 3. Fallback to Hugging Face
    if (_hfApiKey.isNotEmpty) {
      try {
        final messages = [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': userPrompt},
        ];

        final raw = await _callOpenAiCompatibleMessages(
          url: _apiUrl,
          apiKey: _hfApiKey,
          model: _textModel,
          messages: messages,
          maxTokens: (questionCount * 140).clamp(1200, 4096),
          temperature: 0.2,
          providerName: 'Hugging Face',
        );

        return _cleanJsonResponse(raw);
      } catch (_) {}
    }

    throw Exception(
      'Could not generate quiz. Please verify that your HUGGINGFACE_API_KEY, '
      'GEMINI_API_KEY, or OPENROUTER_API_KEY in dev-keys.json is active.',
    );
  }

  // ── 2. Chatbot Screen Support ─────────────────────────────────────────────

  Future<String> askChatbot(
    String userMessage, {
    String? systemPrompt,
    List<Map<String, String>>? history,
    Uint8List? imageBytes,
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

    final userContent = imageBytes == null
        ? userMessage
        : [
            {'type': 'text', 'text': userMessage},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,${base64Encode(imageBytes)}'
              }
            }
          ];
    messages.add({'role': 'user', 'content': userContent});

    return _callMessages(
      messages,
      model: imageBytes == null ? _textModel : _visionModel,
    );
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
    const prompt =
        'Extract all readable text from this image as accurately as possible. '
        'Preserve line breaks, punctuation, and mathematical symbols. '
        'Return only the extracted text; do not summarize or guess unreadable words.';
    final failures = <String>[];

    if (_geminiApiKey.isNotEmpty) {
      try {
        return await _extractTextWithGemini(
          imageBytes,
          mimeType: mimeType,
          prompt: prompt,
        );
      } catch (error) {
        failures.add('Gemini: $error');
      }
    }

    if (_openRouterApiKey.isNotEmpty) {
      try {
        return await _extractTextWithOpenAiCompatibleProvider(
          url: 'https://openrouter.ai/api/v1/chat/completions',
          apiKey: _openRouterApiKey,
          model: 'meta-llama/llama-3.2-11b-vision-instruct:free',
          dataUri: dataUri,
          prompt: prompt,
          providerName: 'OpenRouter',
        );
      } catch (error) {
        failures.add('OpenRouter: $error');
      }
    }

    if (_hfApiKey.isNotEmpty) {
      try {
        return await _extractTextWithOpenAiCompatibleProvider(
          url: _apiUrl,
          apiKey: _hfApiKey,
          model: _visionModel,
          dataUri: dataUri,
          prompt: prompt,
          providerName: 'Hugging Face',
        );
      } catch (error) {
        failures.add('Hugging Face: $error');
      }
    }

    throw Exception(
      'Image text extraction failed. ${failures.join(" | ")}. '
      'Please check your dev-keys.json.',
    );
  }

  // ── Private Provider Implementations ──────────────────────────────────────

  Future<String> _extractTextWithGemini(
    Uint8List imageBytes, {
    required String mimeType,
    required String prompt,
  }) async {
    for (final model in _geminiModels) {
      try {
        final uri = Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$model:generateContent',
          {'key': _geminiApiKey},
        );
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {
                        'inline_data': {
                          'mime_type': mimeType,
                          'data': base64Encode(imageBytes),
                        }
                      },
                    ],
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'maxOutputTokens': 4096,
                },
              }),
            )
            .timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final candidates = decoded['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates.first['content']?['parts'] as List?;
            final text = parts?.map((p) => p['text']).join().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        }
      } catch (_) {}
    }
    throw const FormatException('Gemini OCR unavailable.');
  }

  Future<String> _callGemini(String system, String prompt, int count) async {
    for (final model in _geminiModels) {
      try {
        final url = Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$model:generateContent',
          {'key': _geminiApiKey},
        );

        final response = await http
            .post(
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
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return _cleanJsonResponse(text);
        }
      } catch (_) {}
    }
    throw const FormatException('Gemini request failed.');
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
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('OpenRouter Error ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return _cleanJsonResponse(
        data['choices'][0]['message']['content'] as String);
  }

  Future<String> _callMessages(
    List<Map<String, dynamic>> messages, {
    int maxTokens = 1024,
    double temperature = 0.5,
    String model = _textModel,
  }) async {
    _assertKey();

    // 1. Try Gemini
    if (_geminiApiKey.isNotEmpty) {
      try {
        return await _callGeminiMessages(
          messages,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      } catch (_) {}
    }

    // 2. Try OpenRouter
    if (_openRouterApiKey.isNotEmpty) {
      try {
        final hasImage = _messagesContainImage(messages);
        return await _callOpenAiCompatibleMessages(
          url: 'https://openrouter.ai/api/v1/chat/completions',
          apiKey: _openRouterApiKey,
          model: hasImage
              ? 'meta-llama/llama-3.2-11b-vision-instruct:free'
              : 'meta-llama/llama-3.1-8b-instruct:free',
          messages: messages,
          maxTokens: maxTokens,
          temperature: temperature,
          providerName: 'OpenRouter',
        );
      } catch (_) {}
    }

    // 3. Fallback to Hugging Face
    if (_hfApiKey.isNotEmpty) {
      return await _callOpenAiCompatibleMessages(
        url: _apiUrl,
        apiKey: _hfApiKey,
        model: model,
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
        providerName: 'Hugging Face',
      );
    }

    throw Exception('All AI providers failed. Check your API keys in config/dev-keys.json.');
  }

  Future<String> _callGeminiMessages(
    List<Map<String, dynamic>> messages, {
    required int maxTokens,
    required double temperature,
  }) async {
    for (final model in _geminiModels) {
      try {
        final contents = <Map<String, dynamic>>[];
        final systemPrompts = <String>[];

        for (final message in messages) {
          final role = message['role']?.toString();
          final content = message['content'];
          if (role == 'system') {
            if (content is String && content.trim().isNotEmpty) {
              systemPrompts.add(content.trim());
            }
            continue;
          }
          if (role != 'user' && role != 'assistant') continue;
          final parts = _geminiParts(content);
          if (parts.isNotEmpty) {
            contents.add({
              'role': role == 'assistant' ? 'model' : 'user',
              'parts': parts,
            });
          }
        }

        if (contents.isEmpty) continue;

        final uri = Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$model:generateContent',
          {'key': _geminiApiKey},
        );
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': contents,
                if (systemPrompts.isNotEmpty)
                  'systemInstruction': {
                    'parts': [
                      {'text': systemPrompts.join('\n\n')}
                    ],
                  },
                'generationConfig': {
                  'temperature': temperature,
                  'maxOutputTokens': maxTokens,
                },
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final candidates = decoded['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates.first['content']?['parts'] as List?;
            final text = parts?.map((p) => p['text']).join().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        }
      } catch (_) {}
    }

    throw const FormatException('Gemini message request failed.');
  }

  List<Map<String, dynamic>> _geminiParts(Object? content) {
    if (content is String) {
      return content.trim().isEmpty ? [] : [{'text': content}];
    }
    if (content is! List) return [];

    final parts = <Map<String, dynamic>>[];
    for (final item in content) {
      if (item is! Map) continue;
      if (item['type'] == 'text' && item['text'] is String) {
        parts.add({'text': item['text']});
        continue;
      }
      final imageUrl = (item['image_url'] as Map?)?['url'];
      if (item['type'] != 'image_url' || imageUrl is! String) continue;
      final match = RegExp(
        r'^data:([^;]+);base64,([A-Za-z0-9+/=\r\n]+)$',
      ).firstMatch(imageUrl);
      if (match == null) continue;
      parts.add({
        'inline_data': {
          'mime_type': match.group(1),
          'data': match.group(2)!.replaceAll(RegExp(r'\s'), ''),
        }
      });
    }
    return parts;
  }

  Future<String> _callOpenAiCompatibleMessages({
    required String url,
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required int maxTokens,
    required double temperature,
    required String providerName,
  }) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'max_tokens': maxTokens,
            'temperature': temperature,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(
        '$providerName API error ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    final choices = decoded['choices'] as List?;
    final content = choices?.first?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw FormatException('$providerName returned empty response content.');
    }
    return content.trim();
  }

  Future<String> _extractTextWithOpenAiCompatibleProvider({
    required String url,
    required String apiKey,
    required String model,
    required String dataUri,
    required String prompt,
    required String providerName,
  }) async {
    return _callOpenAiCompatibleMessages(
      url: url,
      apiKey: apiKey,
      model: model,
      messages: [
        {
          'role': 'user',
          'content': [
            {'type': 'image_url', 'image_url': {'url': dataUri}},
            {'type': 'text', 'text': prompt},
          ],
        }
      ],
      maxTokens: 4096,
      temperature: 0.1,
      providerName: providerName,
    );
  }

  bool _messagesContainImage(List<Map<String, dynamic>> messages) =>
      messages.any((message) {
        final content = message['content'];
        return content is List &&
            content.any(
              (item) => item is Map && item['type'] == 'image_url',
            );
      });

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

  String _cleanJsonResponse(String raw) {
    String cleaned = raw.trim();
    cleaned = cleaned
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
    return cleaned;
  }

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
}