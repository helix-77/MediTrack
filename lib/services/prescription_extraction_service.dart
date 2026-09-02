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
You are a medical prescription OCR assistant. You will receive one or more images of a doctor's prescription, which may be handwritten and may mix Bangla and English. Extract only what is visibly present on the page — never infer or guess a medicine name, dosage, or duration that is not legible. If a field is not clearly readable, output null for it rather than guessing.

Return ONLY valid JSON, no prose, no markdown code fences, matching exactly this schema:
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
If the image is unreadable or is not a prescription, return {"error": "unreadable"}.
''';

  OpenRouterClient _getClient() {
    if (_customClient != null) return _customClient;
    return _cachedClient ??= OpenRouterClient(
      apiKey: ApiConfig.openRouterApiKey,
      httpClient: OpenRouterSanitizingHttpClient(),
    );
  }

  Future<PrescriptionDraft> extractPrescription({
    required File imageFile,
    String mimeType = 'image/jpeg',
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

      final request = ChatRequest(
        model: ApiConfig.openRouterModel,
        messages: [
          const Message(
            role: MessageRole.system,
            content: _systemPrompt,
          ),
          Message(
            role: MessageRole.user,
            content: [
              const TextContentItem(
                text:
                    'Extract the medicines and details from this prescription according to the schema.',
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
