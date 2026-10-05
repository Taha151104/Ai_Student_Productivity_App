import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Universal AI Service: Supports Google Gemini, OpenAI (ChatGPT), and Hugging Face.
/// Automatically uses whichever valid key is provided in config/dev-keys.json.
class AiService {
  static String _geminiKey = '';
  static String _hfKey = '';
  static String _openAiKey = '';
  static bool _keysLoaded = false;

  // Endpoints & Models
  static const String _geminiModel = 'gemini-1.5-flash';
  static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _openAiModel = 'gpt-4o-mini';
  static const String _hfUrl = 'https://router.huggingface.co/v1/chat/completions';
  static const String _hfTextModel = 'meta-llama/Llama-3.1-8B-Instruct:fastest';
  static const String _hfVisionModel = 'meta-llama/Llama-3.2-11B-Vision-Instruct:cerebras';

  /// 1. Load keys from --dart-define OR config/dev-keys.json asset
  Future<void> _loadKeys() async {
    if (_keysLoaded) return;

    // Check compile-time environment first
    _geminiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    _hfKey = const String.fromEnvironment('HUGGINGFACE_API_KEY', defaultValue: '');
    _openAiKey = const String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');

    // Fallback to reading config/dev-keys.json directly
    try {
      final rawJson = await rootBundle.loadString('config/dev-keys.json');
      final Map<String, dynamic> data = jsonDecode(rawJson);

      if (_geminiKey.isEmpty) {
        _geminiKey = (data['GEMINI_API_KEY'] ?? '').toString().trim();
      }
      if (_hfKey.isEmpty) {
        _hfKey = (data['HUGGINGFACE_API_KEY'] ?? '').toString().trim();
      }
      if (_openAiKey.isEmpty) {
        _openAiKey = (data['OPENAI_API_KEY'] ?? '').toString().trim();
      }
    } catch (_) {
      // Ignore if asset not found
    }

    _keysLoaded = true;
  }

  // Check valid key formats
  bool get _hasValidGemini => _geminiKey.startsWith('AIza');
  bool get _hasValidOpenAi => _openAiKey.startsWith('sk-');
  bool get _hasValidHf => _hfKey.startsWith('hf_');

  // ── Main Chatbot Function ─────────────────────────────────────────────────

  Future<String> askChatbot(
    String userMessage, {
    String? systemPrompt,
    List<Map<String, String>>? history,
  }) async {
    await _loadKeys();

    // Priority 1: Google Gemini (if valid AIzaSy... key is set)
    if (_hasValidGemini) {
      return _callGemini(userMessage, systemPrompt: systemPrompt, history: history);
    }

    // Priority 2: OpenAI ChatGPT (if valid sk-... key is set)
    if (_hasValidOpenAi) {
      final messages = _buildOpenAiStyleMessages(userMessage, systemPrompt, history);
      return _callOpenAiCompatible(
        url: _openAiUrl,
        apiKey: _openAiKey,
        model: _openAiModel,
        messages: messages,
      );
    }

    // Priority 3: Hugging Face (if valid hf_... token is set)
    if (_hasValidHf) {
      final messages = _buildOpenAiStyleMessages(userMessage, systemPrompt, history);
      return _callOpenAiCompatible(
        url: _hfUrl,
        apiKey: _hfKey,
        model: _hfTextModel,
        messages: messages,
      );
    }

    throw Exception(
      'Koi valid API Key nahi mili!\n'
      'Baraye meherbani config/dev-keys.json mein in mein se koi 1 key lagayein:\n'
      '• GEMINI_API_KEY ("AIzaSy..." se shuru hone wali)\n'
      '• HUGGINGFACE_API_KEY ("hf_..." se shuru hone wali)\n'
      '• OPENAI_API_KEY ("sk-..." se shuru hone wali)',
    );
  }

  List<Map<String, dynamic>> _buildOpenAiStyleMessages(
    String userMessage,
    String? systemPrompt,
    List<Map<String, String>>? history,
  ) {
    final messages = <Map<String, dynamic>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    if (history != null) {
      final recent = history.length > 10 ? history.sublist(history.length - 10) : history;
      messages.addAll(recent);
    }
    messages.add({'role': 'user', 'content': userMessage});
    return messages;
  }

  // ── Provider 1: Google Gemini API ─────────────────────────────────────────

  Future<String> _callGemini(
    String userMessage, {
    String? systemPrompt,
    List<Map<String, String>>? history,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey',
    );

    final contents = <Map<String, dynamic>>[];
    if (history != null) {
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': msg['content'] ?? ''}
          ],
        });
      }
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final body = <String, dynamic>{
      'contents': contents,
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API Error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return 'No response generated.';
    final parts = candidates[0]['content']['parts'] as List?;
    return parts?.map((e) => e['text']).join('') ?? '';
  }

  // ── Provider 2 & 3: ChatGPT (OpenAI) & Hugging Face Router ────────────────

  Future<String> _callOpenAiCompatible({
    required String url,
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    int maxTokens = 1024,
  }) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AI API Error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  // ── Other App Features (Summary, Quiz, Flashcards, Memory) ────────────────

  Future<Map<String, String>> extractMemoryFacts(String userMessage) async {
    final prompt =
        'Extract student facts as JSON using keys (name, subject, study_goal) if mentioned, otherwise return {}: "$userMessage"';
    try {
      final raw = await askChatbot(prompt);
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

  Future<String> generateSummary(String noteText, {String format = 'short'}) {
    final prompt = format == 'short'
        ? 'Summarize the following study notes in 3-4 concise bullet points:\n\n$noteText'
        : 'Provide a detailed, well-structured summary of the following study notes:\n\n$noteText';
    return askChatbot(prompt);
  }

  Future<String> generateQuizJson(String noteText) {
    final prompt =
        'Generate 5 multiple-choice questions from the following study notes. '
        'Respond ONLY with valid JSON: '
        '[{"question": "...", "options": ["...","...","...","..."], "correctAnswer": "..."}]\n\n$noteText';
    return askChatbot(prompt);
  }

  Future<String> generateFlashcardsJson(String noteText) {
    final prompt =
        'Generate 8 flashcards (front/back) from the following study notes. '
        'Respond ONLY with valid JSON: [{"front": "...", "back": "..."}]\n\n$noteText';
    return askChatbot(prompt);
  }

  // ── Vision OCR (Image to Text) ────────────────────────────────────────────

  Future<String> extractTextFromImageBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    await _loadKeys();
    final base64Image = base64Encode(imageBytes);

    // 1. If Gemini key is available, use Gemini Vision
    if (_hasValidGemini) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Extract all visible text from this image accurately.'},
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Image,
                  }
                }
              ]
            }
          ]
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Gemini OCR error: ${response.body}');
      }
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }

    // 2. Otherwise use Hugging Face or OpenAI Vision
    final dataUri = 'data:$mimeType;base64,$base64Image';
    final useOpenAi = _hasValidOpenAi;
    final apiKey = useOpenAi ? _openAiKey : _hfKey;
    final url = useOpenAi ? _openAiUrl : _hfUrl;
    final model = useOpenAi ? _openAiModel : _hfVisionModel;

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
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
                'text': 'Extract and return ALL text visible in this image.',
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
}