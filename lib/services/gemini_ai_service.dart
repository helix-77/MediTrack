import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../logic/ai_action_validator.dart';
import '../logic/auth_guard.dart';

enum GeminiActionType { addMedicine, addBuyItem, unknown }

class GeminiAction {
  final GeminiActionType type;
  final Map<String, dynamic> data;

  GeminiAction({required this.type, required this.data});

  factory GeminiAction.fromJson(Map<String, dynamic> json) {
    final validated = AiActionValidator.validate(json);
    if (validated == null) {
      return GeminiAction(type: GeminiActionType.unknown, data: json);
    }
    final type = switch (validated.type) {
      ValidatedActionType.addMedicine => GeminiActionType.addMedicine,
      ValidatedActionType.addBuyItem => GeminiActionType.addBuyItem,
    };
    return GeminiAction(type: type, data: json);
  }
}

class GeminiChatMessage {
  final String role; // 'system', 'user', 'model'
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
  final GenerativeModel? _customModel;
  GenerativeModel? _cachedModel;

  GeminiAiService({GenerativeModel? model}) : _customModel = model;

  static const String _systemInstructionText = '''
You are MediTrack AI, a helpful, friendly, and expert health and medicine assistant powered by Firebase AI (Gemini).
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

  GenerativeModel _getModel() {
    if (_customModel != null) return _customModel;
    // Reused across calls: constructing a GenerativeModel is not free, and
    // there's no reason to rebuild it on every message.
    return _cachedModel ??= _buildModel();
  }

  GenerativeModel _buildModel() {
    final googleAI = FirebaseAI.googleAI();
    return googleAI.generativeModel(
      model: ApiConfig.geminiModel,
      systemInstruction: Content.system(_systemInstructionText),
      generationConfig: GenerationConfig(
        // Bounds reply length so a runaway/verbose generation can't drag out
        // latency indefinitely. NOTE: this pinned firebase_ai version
        // (2.3.0) doesn't publicly export `ThinkingConfig`, which is the
        // bigger latency lever for "thinking" Flash models — upgrading to
        // firebase_ai >=3.x (which does export it) and setting
        // `thinkingConfig: ThinkingConfig(thinkingBudget: 0)` here is the
        // most impactful next step if replies are still slow.
        maxOutputTokens: 1024,
      ),
    );
  }

  /// Send message to Firebase AI Gemini model
  Future<GeminiChatMessage> sendMessage({
    required List<GeminiChatMessage> history,
    required String userPrompt,
    File? imageFile,
  }) async {
    requireAuthenticatedUser(FirebaseAuth.instance);

    try {
      final model = _getModel();
      final hasImage = imageFile != null && imageFile.existsSync();

      final promptText = userPrompt.trim().isEmpty && hasImage
          ? 'Please analyze this prescription photo and list the detected medicines, dosages, and schedules.'
          : userPrompt;

      late final Content content;
      if (hasImage) {
        final bytes = await imageFile.readAsBytes();
        content = Content.multi([
          TextPart(promptText),
          InlineDataPart('image/jpeg', bytes),
        ]);
      } else {
        content = Content.text(promptText);
      }

      final response = await model.generateContent([content]);
      final rawText = response.text ?? 'No response returned from Gemini AI.';

      final parsedAction = parseActionFromContent(rawText);
      final cleanContent = cleanContentText(rawText);

      return GeminiChatMessage(
        role: 'model',
        content: cleanContent,
        action: parsedAction,
      );
    } catch (e) {
      debugPrint('Firebase AI Gemini Error: $e');
      return GeminiChatMessage(
        role: 'model',
        content:
            '⚠️ Firebase AI Error: $e\n\nEnsure Firebase is initialized and Firebase AI service is active.',
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
