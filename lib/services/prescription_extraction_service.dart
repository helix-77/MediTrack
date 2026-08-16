import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../logic/auth_guard.dart';
import '../logic/prescription_validator.dart';
import '../models/prescription_extraction.dart';

class PrescriptionExtractionService {
  final GenerativeModel? _customModel;

  PrescriptionExtractionService({GenerativeModel? model})
      : _customModel = model;

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

  GenerativeModel _getModel() {
    if (_customModel != null) return _customModel;

    final googleAI = FirebaseAI.googleAI(
      auth: FirebaseAuth.instance,
      appCheck: FirebaseAppCheck.instance,
    );

    return googleAI.generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemPrompt),
    );
  }

  Future<PrescriptionDraft> extractPrescription({
    required File imageFile,
    String mimeType = 'image/jpeg',
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

      final content = Content.multi([
        TextPart('Extract the medicines and details from this prescription according to the schema.'),
        InlineDataPart(mimeType, bytes),
      ]);

      final response = await model.generateContent([content]);
      final rawText = response.text ?? '';

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
      if (errorString.contains('network') || errorString.contains('timeout')) {
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
