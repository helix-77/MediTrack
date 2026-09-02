import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:openrouter/openrouter.dart';

import '../config/api_config.dart';
import '../logic/ai_action_validator.dart';
import '../logic/auth_guard.dart';

enum AiActionType { addMedicine, addBuyItem, unknown }

class AiAction {
  final AiActionType type;
  final Map<String, dynamic> data;

  AiAction({required this.type, required this.data});

  factory AiAction.fromJson(Map<String, dynamic> json) {
    final validated = AiActionValidator.validate(json);
    if (validated == null) {
      return AiAction(type: AiActionType.unknown, data: json);
    }
    final type = switch (validated.type) {
      ValidatedActionType.addMedicine => AiActionType.addMedicine,
      ValidatedActionType.addBuyItem => AiActionType.addBuyItem,
    };
    return AiAction(type: type, data: json);
  }
}

class AiChatMessage {
  final String role; // 'system', 'user', 'model', 'assistant'
  final String content;
  final String? imagePath;
  final DateTime timestamp;
  final AiAction? action;

  AiChatMessage({
    required this.role,
    required this.content,
    this.imagePath,
    DateTime? timestamp,
    this.action,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
}

/// Backwards compatibility aliases for existing codebase & tests
typedef GeminiActionType = AiActionType;
typedef GeminiAction = AiAction;
typedef GeminiChatMessage = AiChatMessage;
typedef GeminiAiService = OpenRouterAiService;

class OpenRouterAiService {
  final OpenRouterClient? _customClient;
  OpenRouterClient? _cachedClient;

  OpenRouterAiService({OpenRouterClient? client}) : _customClient = client;

  static const String _systemInstructionText = '''
You are MediTrack AI, a helpful, friendly, and expert health and medicine assistant powered by OpenRouter.
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

  OpenRouterClient _getClient() {
    if (_customClient != null) return _customClient;
    return _cachedClient ??= OpenRouterClient(
      apiKey: ApiConfig.openRouterApiKey,
    );
  }

  /// Send message to OpenRouter AI model
  Future<AiChatMessage> sendMessage({
    required List<AiChatMessage> history,
    required String userPrompt,
    File? imageFile,
  }) async {
    requireAuthenticatedUser(FirebaseAuth.instance);

    final apiKey = ApiConfig.openRouterApiKey;
    if (apiKey.isEmpty) {
      return AiChatMessage(
        role: 'model',
        content:
            '⚠️ OpenRouter API Key is not configured. Please add OPENROUTER_API_KEY to your .env file.',
      );
    }

    try {
      final client = _getClient();
      final hasImage = imageFile != null && imageFile.existsSync();

      final promptText = userPrompt.trim().isEmpty && hasImage
          ? 'Please analyze this prescription photo and list the detected medicines, dosages, and schedules.'
          : userPrompt;

      final messages = <Message>[
        const Message(
          role: MessageRole.system,
          content: _systemInstructionText,
        ),
      ];

      for (final msg in history) {
        final role = switch (msg.role) {
          'user' => MessageRole.user,
          'assistant' || 'model' => MessageRole.assistant,
          'system' => MessageRole.system,
          _ => MessageRole.user,
        };
        messages.add(Message(role: role, content: msg.content));
      }

      if (hasImage) {
        final bytes = await imageFile.readAsBytes();
        final base64Str = base64Encode(bytes);
        final isPng = imageFile.path.toLowerCase().endsWith('.png');
        final mimeType = isPng ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mimeType;base64,$base64Str';

        messages.add(
          Message(
            role: MessageRole.user,
            content: [
              TextContentItem(text: promptText),
              ImageContentItem(
                imageUrl: ImageUrl(url: dataUri),
              ),
            ],
          ),
        );
      } else {
        messages.add(Message.user(promptText));
      }

      final request = ChatRequest(
        model: ApiConfig.openRouterModel,
        messages: messages,
        maxTokens: 1024,
      );

      final response = await client.chatCompletion(request);
      final rawText = response.content ?? 'No response returned from OpenRouter AI.';

      final parsedAction = parseActionFromContent(rawText);
      final cleanContent = cleanContentText(rawText);

      return AiChatMessage(
        role: 'model',
        content: cleanContent,
        action: parsedAction,
      );
    } on RateLimitException catch (e) {
      debugPrint('OpenRouter rate limit: $e');
      return AiChatMessage(
        role: 'model',
        content: '⚠️ Rate limit reached on OpenRouter. Please try again shortly.',
      );
    } on AuthenticationException catch (e) {
      debugPrint('OpenRouter auth error: $e');
      return AiChatMessage(
        role: 'model',
        content: '⚠️ OpenRouter Authentication failed. Please check your OPENROUTER_API_KEY in .env.',
      );
    } on OpenRouterException catch (e) {
      debugPrint('OpenRouter API error: ${e.message} (code: ${e.code})');
      return AiChatMessage(
        role: 'model',
        content: '⚠️ OpenRouter Error: ${e.message}',
      );
    } catch (e) {
      debugPrint('OpenRouter AI Service Error: $e');
      return AiChatMessage(
        role: 'model',
        content:
            '⚠️ OpenRouter AI Error: $e\n\nPlease check your internet connection and API key.',
      );
    }
  }

  /// Extracts JSON Action block from response text
  static AiAction? parseActionFromContent(String rawContent) {
    try {
      final jsonBlockRegex = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```');
      final match = jsonBlockRegex.firstMatch(rawContent);
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return AiAction.fromJson(map);
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
