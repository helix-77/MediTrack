import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:openrouter/openrouter.dart';

import '../config/api_config.dart';
import '../core/network/openrouter_sanitizing_client.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';
import '../models/medicine_reference.dart';
import '../logic/ai_action_validator.dart';
import '../logic/auth_guard.dart';

enum AiActionType {
  addMedicine,
  updateMedicine,
  deleteMedicine,
  addBuyItem,
  updateBuyItem,
  deleteBuyItem,
  unknown,
}

class AiAction {
  final AiActionType type;
  final Map<String, dynamic> data;
  bool isExecuted;

  AiAction({
    required this.type,
    required this.data,
    this.isExecuted = false,
  });

  factory AiAction.fromJson(Map<String, dynamic> json) {
    final validated = AiActionValidator.validate(json);
    if (validated == null) {
      return AiAction(type: AiActionType.unknown, data: json);
    }
    final type = switch (validated.type) {
      ValidatedActionType.addMedicine => AiActionType.addMedicine,
      ValidatedActionType.updateMedicine => AiActionType.updateMedicine,
      ValidatedActionType.deleteMedicine => AiActionType.deleteMedicine,
      ValidatedActionType.addBuyItem => AiActionType.addBuyItem,
      ValidatedActionType.updateBuyItem => AiActionType.updateBuyItem,
      ValidatedActionType.deleteBuyItem => AiActionType.deleteBuyItem,
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

  static String buildSystemInstruction({
    List<Medicine>? userMedicines,
    List<BuyListItem>? userBuyList,
    List<MedicineReference>? catalogMatches,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are MediTrack AI, a helpful, friendly, and expert health and medicine assistant powered by OpenRouter.',
    );
    buffer.writeln(
      'Your goal is to help users manage their medication routines, grocery/buy lists, query their health database, analyze prescription photos, and provide accurate health and wellness advice in Bangladesh.',
    );
    buffer.writeln();

    if (userMedicines != null && userMedicines.isNotEmpty) {
      buffer.writeln('CURRENT USER ROUTINE MEDICINES (FROM DATABASE):');
      for (final m in userMedicines) {
        final times = m.schedule.doseTimes.join(', ');
        buffer.writeln(
          '- ID: "${m.id}", Name: "${m.name}", Strength: "${m.strength ?? 'N/A'}", Form: "${m.dosageForm ?? 'tablet'}", Stock: ${m.quantityCurrent} (Low: ${m.lowStockThreshold}), Schedule: ${m.schedule.timesPerDay}x/day at [$times], Active: ${m.schedule.active}',
        );
      }
      buffer.writeln();
    } else if (userMedicines != null) {
      buffer.writeln(
        'CURRENT USER ROUTINE MEDICINES (FROM DATABASE): None currently saved in routine.',
      );
      buffer.writeln();
    }

    if (userBuyList != null && userBuyList.isNotEmpty) {
      buffer.writeln('CURRENT USER BUY LIST (FROM DATABASE):');
      for (final b in userBuyList) {
        buffer.writeln(
          '- ID: "${b.id}", Name: "${b.name}", Qty: ${b.quantityToBuy}, Purchased: ${b.isPurchased}',
        );
      }
      buffer.writeln();
    } else if (userBuyList != null) {
      buffer.writeln('CURRENT USER BUY LIST (FROM DATABASE): Empty.');
      buffer.writeln();
    }

    if (catalogMatches != null && catalogMatches.isNotEmpty) {
      buffer.writeln('BANGLADESH MEDICINE CATALOG REFERENCES (FROM DATABASE):');
      for (final c in catalogMatches) {
        final price =
            c.unitPriceBdt != null ? '৳${c.unitPriceBdt!.toStringAsFixed(2)}' : 'N/A';
        buffer.writeln(
          '- Brand: "${c.brandName}", Generic: "${c.genericName}", Form: "${c.dosageForm ?? 'N/A'}", Strength: "${c.strength ?? 'N/A'}", Mfr: "${c.manufacturer ?? 'N/A'}", Unit Price: $price',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('''
DATABASE QUERIES & CRUD INSTRUCTIONS:
- You have direct access to the user's active routine, buy list, and Bangladesh medicine catalog database above.
- Use this database for reference to answer queries accurately (e.g. "What medicines do I take?", "How much Napa do I have left?", "What is the price of Napa in Bangladesh?", "Is Napa on my buy list?").
- When the user asks to add, update, or delete items, provide a friendly explanation in natural text AND append the EXACT corresponding JSON action block at the very end of your response:

1. ADD MEDICINE TO ROUTINE:
```json
{
  "action": "ADD_MEDICINE",
  "name": "Paracetamol",
  "dosage": "500mg",
  "form": "tablet",
  "frequency": "2 times daily",
  "doseTimes": ["08:00", "20:00"],
  "stock": 30
}
```

2. UPDATE MEDICINE IN ROUTINE (stock, dosage, times, or frequency):
```json
{
  "action": "UPDATE_MEDICINE",
  "medicineId": "<ID from database if known>",
  "name": "Paracetamol",
  "stock": 25,
  "doseTimes": ["09:00", "21:00"]
}
```

3. DELETE MEDICINE FROM ROUTINE:
```json
{
  "action": "DELETE_MEDICINE",
  "medicineId": "<ID from database if known>",
  "name": "Paracetamol"
}
```

4. ADD ITEM TO BUY LIST:
```json
{
  "action": "ADD_BUY_ITEM",
  "name": "Vitamin C 1000mg",
  "quantity": 1
}
```

5. UPDATE ITEM IN BUY LIST (quantity or purchased status):
```json
{
  "action": "UPDATE_BUY_ITEM",
  "itemId": "<ID from database if known>",
  "name": "Vitamin C 1000mg",
  "quantity": 3
}
```

6. DELETE ITEM FROM BUY LIST:
```json
{
  "action": "DELETE_BUY_ITEM",
  "itemId": "<ID from database if known>",
  "name": "Vitamin C 1000mg"
}
```

7. If analyzing a prescription image, list the detected medicines, dosage details, and offer to add them to their routine.

Be clear, encouraging, and informative. Remind users to consult qualified healthcare professionals for medical emergencies.
''');

    return buffer.toString();
  }

  OpenRouterClient _getClient() {
    if (_customClient != null) return _customClient;
    return _cachedClient ??= OpenRouterClient(
      apiKey: ApiConfig.openRouterApiKey,
      httpClient: OpenRouterSanitizingHttpClient(),
    );
  }

  /// Send message to OpenRouter AI model with optional DB and catalog context
  Future<AiChatMessage> sendMessage({
    required List<AiChatMessage> history,
    required String userPrompt,
    File? imageFile,
    List<Medicine>? userMedicines,
    List<BuyListItem>? userBuyList,
    List<MedicineReference>? catalogMatches,
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

      final systemInstruction = buildSystemInstruction(
        userMedicines: userMedicines,
        userBuyList: userBuyList,
        catalogMatches: catalogMatches,
      );

      final messages = <Message>[
        Message(
          role: MessageRole.system,
          content: systemInstruction,
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
        model: hasImage
            ? ApiConfig.openRouterVisionModels.first
            : ApiConfig.openRouterModel,
        models: hasImage ? ApiConfig.openRouterVisionModels : null,
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
