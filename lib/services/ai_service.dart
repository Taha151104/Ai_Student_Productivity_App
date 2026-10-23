import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AiService {
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );

  Future<String> generateQuizJson(
    String noteText, {
    int questionCount = 10,
    String? userFocusInstruction,
    String? topicHint,
  }) async {
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

    final raw = await _callMessages(
      [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': userPrompt},
      ],
      maxTokens: (questionCount * 150).clamp(1000, 4000),
      temperature: 0.2,
      responseMimeType: 'application/json',
    );
    return _cleanJsonResponse(raw);
  }

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
      messages.addAll(
        history.length > 10 ? history.sublist(history.length - 10) : history,
      );
    }

    final content = imageBytes == null
        ? userMessage
        : [
            {'type': 'text', 'text': userMessage},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,${base64Encode(imageBytes)}',
              },
            },
          ];
    messages.add({'role': 'user', 'content': content});
    return _callMessages(messages);
  }

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
      final raw = await _callMessages(
        [
          {'role': 'user', 'content': prompt},
        ],
        maxTokens: 256,
        temperature: 0.1,
        responseMimeType: 'application/json',
      );
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end <= start) return {};
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is String &&
              (entry.value as String).trim().isNotEmpty)
            entry.key.toString(): (entry.value as String).trim(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<String> generateSummary(String noteText, {String format = 'short'}) {
    final prompt = format == 'short'
        ? 'Summarize the following study notes in 3-4 concise sentences:\n\n$noteText'
        : 'Provide a detailed, well-structured summary of the following study notes:\n\n$noteText';
    return _callText(prompt);
  }

  Future<String> generateFlashcardsJson(String noteText) async {
    final prompt =
        'Generate 8 flashcards (front/back) from the following study notes. '
        'Respond ONLY with valid JSON: [{"front": "...", "back": "..."}]\n\n$noteText';
    return _cleanJsonResponse(await _callText(prompt));
  }

  Future<String> extractTextFromImageBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) {
    const prompt =
        'Extract all readable text from this image as accurately as possible. '
        'Preserve line breaks, punctuation, and mathematical symbols. '
        'Return only the extracted text; do not summarize or guess unreadable words.';
    return _callMessages(
      [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,${base64Encode(imageBytes)}',
              },
            },
          ],
        },
      ],
      maxTokens: 4096,
      temperature: 0.1,
    );
  }

  Future<String> _callMessages(
    List<Map<String, dynamic>> messages, {
    int maxTokens = 1024,
    double temperature = 0.5,
    String? responseMimeType,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not configured. Build or run the app with '
        '`--dart-define-from-file=config/dev-keys.json`.',
      );
    }

    final systemPrompts = <String>[];
    final contents = <Map<String, dynamic>>[];
    for (final message in messages) {
      final role = message['role'];
      final content = message['content'];
      if (role == 'system') {
        if (content is! String) {
          throw const FormatException('Invalid Gemini system instruction.');
        }
        if (content.trim().isNotEmpty) systemPrompts.add(content.trim());
        continue;
      }
      if (role != 'user' && role != 'assistant') {
        throw const FormatException('Unsupported Gemini message role.');
      }
      final parts = _geminiParts(content);
      if (parts.isNotEmpty) {
        contents.add({
          'role': role == 'assistant' ? 'model' : 'user',
          'parts': parts,
        });
      }
    }
    if (contents.isEmpty) {
      throw const FormatException('The AI request has no prompt content.');
    }

    final generationConfig = <String, dynamic>{
      'maxOutputTokens': maxTokens.clamp(64, 8192),
      'temperature': temperature.clamp(0.0, 1.0),
      if (responseMimeType != null) 'responseMimeType': responseMimeType,
    };
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey.trim(),
            },
            body: jsonEncode({
              'contents': contents,
              if (systemPrompts.isNotEmpty)
                'systemInstruction': {
                  'parts': [
                    {'text': systemPrompts.join('\n\n')},
                  ],
                },
              'generationConfig': generationConfig,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw Exception('The Gemini request timed out. Please try again.');
    } on http.ClientException catch (error) {
      throw Exception(
        'Could not connect to Gemini. Check your internet connection. '
        '(${error.message})',
      );
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected Gemini response.');
      }
      data = decoded;
    } on FormatException {
      throw Exception(
        'Gemini returned an invalid response (${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      final error = data['error'];
      final message = error is Map ? error['message'] : null;
      throw Exception(
        'Gemini request failed (${response.statusCode}): '
        '${message is String ? message : 'Unknown API error.'}',
      );
    }

    final candidates = data['candidates'];
    final candidate = candidates is List && candidates.isNotEmpty
        ? candidates.first
        : null;
    final responseContent =
        candidate is Map ? candidate['content'] : null;
    final responseParts =
        responseContent is Map ? responseContent['parts'] : null;
    final text = responseParts is List
        ? responseParts
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join()
        : null;
    if (text is! String || text.trim().isEmpty) {
      final promptFeedback = data['promptFeedback'];
      final blockReason =
          promptFeedback is Map ? promptFeedback['blockReason'] : null;
      throw FormatException(
        blockReason is String
            ? 'Gemini blocked the prompt: $blockReason.'
            : 'Gemini returned no text. Please try a different prompt.',
      );
    }
    return text.trim();
  }

  List<Map<String, dynamic>> _geminiParts(dynamic content) {
    final values = content is List ? content : [content];
    final parts = <Map<String, dynamic>>[];
    for (final value in values) {
      if (value is String) {
        if (value.trim().isNotEmpty) parts.add({'text': value});
        continue;
      }
      if (value is! Map) {
        throw const FormatException('Invalid Gemini message content.');
      }
      if (value['type'] == 'text' && value['text'] is String) {
        parts.add({'text': value['text']});
        continue;
      }
      if (value['type'] == 'image_url') {
        final imageUrl = value['image_url'];
        final dataUri = imageUrl is Map ? imageUrl['url'] : null;
        final match = dataUri is String
            ? RegExp(
                r'^data:(image/(?:jpeg|png|webp));base64,([A-Za-z0-9+/]+={0,2})$',
              ).firstMatch(dataUri)
            : null;
        if (match == null) {
          throw const FormatException('Invalid or unsupported image data.');
        }
        parts.add({
          'inlineData': {
            'mimeType': match.group(1),
            'data': match.group(2),
          },
        });
        continue;
      }
      throw const FormatException('Unsupported Gemini message content.');
    }
    return parts;
  }

  String _optimizeTextForTokenBudget({
    required String fullText,
    required String userFocus,
  }) {
    if (fullText.length <= 12000) return fullText;
    final lowerFocus = userFocus.toLowerCase();
    final lectureMatch = RegExp(
      r'(?:lecture|lesson|chapter|module|topic)\s*([0-9ivx]+)',
      caseSensitive: false,
    ).firstMatch(lowerFocus);
    if (lectureMatch != null) {
      final index = fullText.toLowerCase().indexOf(lectureMatch.group(0)!);
      if (index != -1) {
        return fullText.substring(
            index, (index + 10000).clamp(0, fullText.length));
      }
    }
    return fullText.substring(0, 12000);
  }

  String _cleanJsonResponse(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'^\s*```(?:json)?', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
        .trim();

    final firstBracket = cleaned.indexOf('[');
    final firstBrace = cleaned.indexOf('{');
    final start =
        [firstBracket, firstBrace].where((index) => index != -1).fold<int?>(
              null,
              (best, index) => best == null || index < best ? index : best,
            );
    if (start != null) {
      final end = [
        cleaned.lastIndexOf(']'),
        cleaned.lastIndexOf('}'),
      ].where((index) => index != -1).fold<int?>(
            null,
            (best, index) => best == null || index > best ? index : best,
          );
      if (end != null && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
    }
    return cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
  }

  Future<String> _callText(String prompt) => _callMessages([
        {'role': 'user', 'content': prompt},
      ]);
}
