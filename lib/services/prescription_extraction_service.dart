import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../logic/auth_guard.dart';
import '../logic/prescription_validator.dart';
import '../models/prescription_extraction.dart';

class PrescriptionExtractionService {
  final GenerativeModel? _customModel;
  GenerativeModel? _cachedModel;

  PrescriptionExtractionService({GenerativeModel? model})
      : _customModel = model;

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

  GenerativeModel _getModel() {
    if (_customModel != null) return _customModel;
    return _cachedModel ??= _buildModel();
  }

  GenerativeModel _buildModel() {
    final googleAI = FirebaseAI.googleAI();

    return googleAI.generativeModel(
      model: ApiConfig.geminiModel,
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        maxOutputTokens: 2048,
      ),
    );
  }

  /// Extracts prescription details using Firebase AI Logic (Gemini) with
  /// on-device OCR text assistance.
  Future<PrescriptionDraft> extractPrescription({
    required File imageFile,
    String mimeType = 'image/jpeg',
    String? onDeviceOcrText,
  }) async {
    requireAuthenticatedUser(FirebaseAuth.instance);

    if (!imageFile.existsSync()) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.unreadable,
        'Prescription image file does not exist on disk.',
      );
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final model = _getModel();

      var effectiveMimeType = mimeType;
      final pathLower = imageFile.path.toLowerCase();
      if (pathLower.endsWith('.png')) {
        effectiveMimeType = 'image/png';
      } else if (pathLower.endsWith('.webp')) {
        effectiveMimeType = 'image/webp';
      } else if (pathLower.endsWith('.gif')) {
        effectiveMimeType = 'image/gif';
      } else if (pathLower.endsWith('.jpg') || pathLower.endsWith('.jpeg')) {
        effectiveMimeType = 'image/jpeg';
      }

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

      final content = Content.multi([
        TextPart(userPromptBuffer.toString()),
        InlineDataPart(effectiveMimeType, bytes),
      ]);

      final response = await model.generateContent([content]);
      final rawText = response.text ?? '';
      debugPrint('Prescription extraction raw response from Firebase AI: $rawText');

      if (rawText.trim().isEmpty) {
        throw PrescriptionExtractionException(
          PrescriptionErrorType.emptyExtraction,
          'Empty response from AI extraction model.',
        );
      }

      return PrescriptionValidator.parseAndValidate(rawText);
    } on PrescriptionExtractionException {
      rethrow;
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
