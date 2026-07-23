import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum GeminiActionType { addMedicine, addBuyItem, unknown }

class GeminiAction {
  final GeminiActionType type;
  final Map<String, dynamic> data;

  GeminiAction({required this.type, required this.data});

  factory GeminiAction.fromJson(Map<String, dynamic> json) {
    final actionStr = (json['action'] as String?)?.toUpperCase() ?? '';
    GeminiActionType type = GeminiActionType.unknown;
    if (actionStr == 'ADD_MEDICINE') {
      type = GeminiActionType.addMedicine;
    } else if (actionStr == 'ADD_BUY_ITEM') {
      type = GeminiActionType.addBuyItem;
    }
    return GeminiAction(type: type, data: json);
  }
}

class GeminiChatMessage {
  final String role; // 'system', 'user', 'model' / 'assistant'
  final String content;
  final String? imagePath;
  final DateTime timestamp;
  final GeminiAction? action;

  GeminiChatMessage({
    required this.role,
    required this.content,
    this.imagePath,
    DateTime? timestamp,
    this.action,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
}

class GeminiAiService {
  final String? apiKeyOverride;
  final http.Client _client;

  GeminiAiService({this.apiKeyOverride, http.Client? client})
      : _client = client ?? http.Client();

  String _getApiKey(String? runtimeKey) {
    if (runtimeKey != null && runtimeKey.trim().isNotEmpty) {
      return runtimeKey.trim();
    }
    if (apiKeyOverride != null && apiKeyOverride!.trim().isNotEmpty) {
      return apiKeyOverride!.trim();
    }
    return ApiConfig.geminiApiKey;
  }

  static const String _systemInstruction = '''
You are MediTrack AI, a helpful, friendly, and expert health and medicine assistant powered by Google Gemini.
Your goal is to help users manage their medication routines, grocery/buy lists, analyze prescription photos, and provide accurate health and wellness advice.

IMPORTANT INSTRUCTION FOR ACTIONS:
1. If the user wants to add a medicine to their routine/schedule, give a friendly confirmation text AND include a JSON action block at the end of your response formatted EXACTLY like this:
```json
{
  "action": "ADD_MEDICINE",
  "name": "Paracetamol",
  "dosage": "500mg",
  "frequency": "2 times daily",
  "stock": 30
}
```

2. If the user wants to add an item to their grocery/buy list, give a friendly confirmation text AND include a JSON action block formatted EXACTLY like this:
```json
{
  "action": "ADD_BUY_ITEM",
  "name": "Vitamin C 1000mg",
  "quantity": 1
}
```

3. If analyzing a prescription image, list the detected medicines, dosage details, and offer to add them to their routine.
Be clear, encouraging, and informative. Remind users to consult qualified healthcare professionals for medical emergencies.
''';

  /// Send a message to Google Gemini API
  Future<GeminiChatMessage> sendMessage({
    required List<GeminiChatMessage> history,
    required String userPrompt,
    File? imageFile,
    String? runtimeApiKey,
  }) async {
    final apiKey = _getApiKey(runtimeApiKey);
    if (apiKey == 'YOUR_GEMINI_API_KEY_HERE' || apiKey.isEmpty) {
      return GeminiChatMessage(
        role: 'model',
        content:
            '⚠️ Gemini API Key is not set!\n\nPlease paste your Gemini API Key in `.env` (as `GEMINI_API_KEY=your_key`) or tap the settings icon in the top right to configure it.',
      );
    }

    final contents = <Map<String, dynamic>>[];

    for (final msg in history) {
      if (msg.role != 'system') {
        final geminiRole = msg.isUser ? 'user' : 'model';
        contents.add({
          'role': geminiRole,
          'parts': [
            {'text': msg.content}
          ]
        });
      }
    }

    final userParts = <Map<String, dynamic>>[];

    if (imageFile != null && imageFile.existsSync()) {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      userParts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Image,
        }
      });
    }

    userParts.add({
      'text': userPrompt.isEmpty && imageFile != null
          ? 'Please analyze this prescription image and summarize the medicines.'
          : userPrompt
    });

    contents.add({'role': 'user', 'parts': userParts});

    final url = Uri.parse(
      '${ApiConfig.geminiBaseUrl}/models/${ApiConfig.geminiModel}:generateContent?key=$apiKey',
    );

    final payload = {
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
      }
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final firstCandidate = candidates[0] as Map<String, dynamic>;
          final contentObj = firstCandidate['content'] as Map<String, dynamic>?;
          final parts = contentObj?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final rawContent = parts[0]['text'] as String? ?? '';

            final parsedAction = parseActionFromContent(rawContent);
            final cleanContent = cleanContentText(rawContent);

            return GeminiChatMessage(
              role: 'model',
              content: cleanContent,
              action: parsedAction,
            );
          }
        }
        return GeminiChatMessage(
          role: 'model',
          content: 'Received an empty response from Gemini AI.',
        );
      } else {
        return GeminiChatMessage(
          role: 'model',
          content:
              '⚠️ Gemini API Error (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      return GeminiChatMessage(
        role: 'model',
        content: '⚠️ Failed to connect to Gemini API: $e',
      );
    }
  }

  /// Extracts JSON Action block from response text
  static GeminiAction? parseActionFromContent(String rawContent) {
    try {
      final jsonBlockRegex = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```');
      final match = jsonBlockRegex.firstMatch(rawContent);
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return GeminiAction.fromJson(map);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Cleans out ```json ... ``` blocks from user-visible text
  static String cleanContentText(String rawContent) {
    return rawContent
        .replaceAll(RegExp(r'```json\s*\{[\s\S]*?\}\s*```'), '')
        .trim();
  }
}
