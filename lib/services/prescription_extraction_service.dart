import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:openrouter/openrouter.dart';

import '../config/api_config.dart';
import '../core/network/openrouter_sanitizing_client.dart';
import '../logic/auth_guard.dart';
import '../logic/prescription_validator.dart';
import '../models/prescription_extraction.dart';

class PrescriptionExtractionService {
  final OpenRouterClient? _customClient;
  OpenRouterClient? _cachedClient;

  PrescriptionExtractionService({OpenRouterClient? client})
      : _customClient = client;

  static const String _systemPrompt = '''
You are an expert medical prescription assistant. You are analyzing a doctor's prescription which may be handwritten, printed, or mixed English and Bengali.
You will receive:
1. The prescription image.
2. Optional on-device OCR recognized text lines extracted directly from the image to help you decipher medicine names and instructions.

Extract all detected medicines, dosages, frequencies, doctor details, and visit date according to this JSON schema:
{
  "schema_version": 1,
  "doctor_name": null,
  "patient_name": null,
  "date": null,
  "medicines": [
    {
      "name": "Napa",
      "strength": "500 mg",
      "form": "tablet",
      "frequency_per_day": 3,
      "duration_days": 5,
      "instructions": "after meal",
      "confidence": "high"
    }
  ]
}

CRITICAL RULES:
1. Extract whatever medicines, strengths, forms, or instructions you can identify from the image and OCR text.
2. If a medicine name or schedule is partially unclear, extract your best interpretation and set confidence to "medium" or "low" so the user can verify it.
3. If specific fields (doctor_name, date, instructions) are not present or not readable, set them to null.
4. Only return {"error": "unreadable"} if the image contains NO medical text whatsoever, is completely blank, or has zero recognizable words.
5. Return ONLY the raw JSON object, without any prose, markdown explanations, or code blocks.
''';

  OpenRouterClient _getClient() {
    if (_customClient != null) return _customClient;
    return _cachedClient ??= OpenRouterClient(
      apiKey: ApiConfig.openRouterApiKey,
      httpClient: OpenRouterSanitizingHttpClient(),
    );
  }

  /// Extracts prescription details using OpenRouter multimodal vision with
  /// on-device OCR text assistance.
  Future<PrescriptionDraft> extractPrescription({
    required File imageFile,
    String mimeType = 'image/jpeg',
    String? onDeviceOcrText,
  }) async {
    requireAuthenticatedUser(FirebaseAuth.instance);

    final apiKey = ApiConfig.openRouterApiKey;
    if (apiKey.isEmpty) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.unknown,
        'OpenRouter API Key is not configured. Please add OPENROUTER_API_KEY to your .env file.',
      );
    }

    if (!imageFile.existsSync()) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.unreadable,
        'Prescription image file does not exist on disk.',
      );
    }

    try {
      final client = _getClient();
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dataUri = 'data:$mimeType;base64,$base64Image';

      final userPromptBuffer = StringBuffer(
        'Extract all medicines and details from this prescription according to the schema.',
      );
      if (onDeviceOcrText != null && onDeviceOcrText.trim().isNotEmpty) {
        userPromptBuffer.writeln();
        userPromptBuffer.writeln();
        userPromptBuffer.writeln(
          'On-device text scanner detected the following text from this image for your reference:',
        );
        userPromptBuffer.writeln('"""');
        userPromptBuffer.writeln(onDeviceOcrText.trim());
        userPromptBuffer.writeln('"""');
      }

      final request = ChatRequest(
        model: ApiConfig.openRouterModel,
        models: const [
          'minimax/minimax-m3:free',
          'google/gemma-4-31b-it:free',
          'google/gemma-4-26b-a4b-it:free',
          'dots-studio/dots-3-note-preview:free',
          'openrouter/free',
        ],
        messages: [
          const Message(
            role: MessageRole.system,
            content: _systemPrompt,
          ),
          Message(
            role: MessageRole.user,
            content: [
              TextContentItem(
                text: userPromptBuffer.toString(),
              ),
              ImageContentItem(
                imageUrl: ImageUrl(url: dataUri),
              ),
            ],
          ),
        ],
        maxTokens: 2048,
      );

      final response = await client.chatCompletion(request);
      final rawText = response.content ?? '';

      if (rawText.trim().isEmpty) {
        throw PrescriptionExtractionException(
          PrescriptionErrorType.emptyExtraction,
          'Empty response from AI extraction model.',
        );
      }

      return PrescriptionValidator.parseAndValidate(rawText);
    } on PrescriptionExtractionException {
      rethrow;
    } on RateLimitException catch (e) {
      debugPrint('Prescription extraction rate limit: $e');
      throw PrescriptionExtractionException(
        PrescriptionErrorType.quotaLimit,
        'AI service quota or rate limit reached. Please try again shortly.',
      );
    } on AuthenticationException catch (e) {
      debugPrint('Prescription extraction auth error: $e');
      throw PrescriptionExtractionException(
        PrescriptionErrorType.unknown,
        'OpenRouter authentication failed: ${e.message}',
      );
    } on OpenRouterException catch (e) {
      debugPrint('Prescription extraction API error: $e');
      throw PrescriptionExtractionException(
        PrescriptionErrorType.unknown,
        'OpenRouter API error: ${e.message}',
      );
    } catch (e) {
      debugPrint('PrescriptionExtractionService Error: $e');
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('network') ||
          errorString.contains('timeout') ||
          errorString.contains('socketexception')) {
        throw PrescriptionExtractionException(
          PrescriptionErrorType.networkTimeout,
          'Network connection timed out. Please check your internet connection.',
        );
      } else if (errorString.contains('quota') ||
          errorString.contains('rate') ||
          errorString.contains('429') ||
          errorString.contains('resource_exhausted')) {
        throw PrescriptionExtractionException(
          PrescriptionErrorType.quotaLimit,
          'AI service quota limit reached. Please try again shortly.',
        );
      } else {
        throw PrescriptionExtractionException(
          PrescriptionErrorType.unknown,
          'Failed to extract prescription: $e',
        );
      }
    }
  }
}
