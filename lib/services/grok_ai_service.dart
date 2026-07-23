import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum GrokActionType { addMedicine, addBuyItem, unknown }

class GrokAction {
  final GrokActionType type;
  final Map<String, dynamic> data;

  GrokAction({required this.type, required this.data});

  factory GrokAction.fromJson(Map<String, dynamic> json) {
    final actionStr = (json['action'] as String?)?.toUpperCase() ?? '';
    GrokActionType type = GrokActionType.unknown;
    if (actionStr == 'ADD_MEDICINE') {
      type = GrokActionType.addMedicine;
    } else if (actionStr == 'ADD_BUY_ITEM') {
      type = GrokActionType.addBuyItem;
    }
    return GrokAction(type: type, data: json);
  }
}

class GrokChatMessage {
  final String role; // 'system', 'user', 'assistant'
  final String content;
  final String? imagePath;
  final DateTime timestamp;
  final GrokAction? action;

  GrokChatMessage({
    required this.role,
    required this.content,
    this.imagePath,
    DateTime? timestamp,
    this.action,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
}

class GrokAiService {
  final String? apiKeyOverride;
  final http.Client _client;

  GrokAiService({this.apiKeyOverride, http.Client? client})
      : _client = client ?? http.Client();

  String _getApiKey(String? runtimeKey) {
    if (runtimeKey != null && runtimeKey.trim().isNotEmpty) {
      return runtimeKey.trim();
    }
    if (apiKeyOverride != null && apiKeyOverride!.trim().isNotEmpty) {
      return apiKeyOverride!.trim();
    }
    return ApiConfig.grokApiKey;
  }

  static const String _systemPrompt = '''
You are MediTrack AI, a helpful, friendly, and expert health and medicine assistant.
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

  /// Send a message to xAI Grok API (supports vision if imageFile is attached)
  Future<GrokChatMessage> sendMessage({
    required List<GrokChatMessage> history,
    required String userPrompt,
    File? imageFile,
    String? runtimeApiKey,
  }) async {
    final apiKey = _getApiKey(runtimeApiKey);
    if (apiKey == 'PASTE_YOUR_GROK_API_KEY_HERE' || apiKey.isEmpty) {
      return GrokChatMessage(
        role: 'assistant',
        content:
            '⚠️ Grok API Key is not set!\n\nPlease paste your Grok API Key in `lib/config/api_config.dart` or tap the settings icon in the top right to configure it.',
      );
    }

    final hasImage = imageFile != null && imageFile.existsSync();
    final model =
        hasImage ? ApiConfig.grokVisionModel : ApiConfig.grokTextModel;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    for (final msg in history) {
      if (msg.role != 'system') {
        messages.add({'role': msg.role, 'content': msg.content});
      }
    }

    if (hasImage) {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userPrompt.isEmpty ? 'Please analyze this prescription image and summarize the medicines.' : userPrompt},
          {
            'type': 'image_url',
            'image_url': {'url': dataUrl}
          }
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': userPrompt});
    }

    final url = Uri.parse('${ApiConfig.grokBaseUrl}/chat/completions');
    final payload = {
      'model': model,
      'messages': messages,
      'temperature': 0.7,
    };

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final firstChoice = choices[0] as Map<String, dynamic>;
          final messageObj = firstChoice['message'] as Map<String, dynamic>?;
          final rawContent = messageObj?['content'] as String? ?? '';

          final parsedAction = parseActionFromContent(rawContent);
          final cleanContent = cleanContentText(rawContent);

          return GrokChatMessage(
            role: 'assistant',
            content: cleanContent,
            action: parsedAction,
          );
        } else {
          return GrokChatMessage(
            role: 'assistant',
            content: 'Received an empty response from Grok AI.',
          );
        }
      } else {
        return GrokChatMessage(
          role: 'assistant',
          content:
              '⚠️ Grok API Error (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      return GrokChatMessage(
        role: 'assistant',
        content: '⚠️ Failed to connect to Grok AI API: $e',
      );
    }
  }

  /// Extracts JSON Action block from Grok text response
  static GrokAction? parseActionFromContent(String rawContent) {
    try {
      final jsonBlockRegex = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```');
      final match = jsonBlockRegex.firstMatch(rawContent);
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return GrokAction.fromJson(map);
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
