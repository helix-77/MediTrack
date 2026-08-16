import 'dart:convert';
import '../models/prescription_extraction.dart';

enum PrescriptionErrorType {
  unreadable,
  malformedJson,
  invalidSchema,
  emptyExtraction,
  networkTimeout,
  quotaLimit,
  unknown,
}

class PrescriptionExtractionException implements Exception {
  final PrescriptionErrorType type;
  final String message;

  PrescriptionExtractionException(this.type, this.message);

  @override
  String toString() => 'PrescriptionExtractionException($type): $message';
}

class PrescriptionValidator {
  /// Strips markdown code blocks and trims whitespace.
  static String cleanJsonText(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  /// Parses raw LLM text, validates JSON and schema, applies clamping / confidence heuristics.
  static PrescriptionDraft parseAndValidate(String rawContent) {
    final cleaned = cleanJsonText(rawContent);

    if (cleaned.isEmpty) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.emptyExtraction,
        'Empty response received from AI model.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (e) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.malformedJson,
        'Failed to parse JSON response: $e',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.invalidSchema,
        'Expected a JSON object root.',
      );
    }

    // Check for explicit unreadable error from model prompt contract
    if (decoded['error'] == 'unreadable' || decoded['error'] == 'unreadable_prescription') {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.unreadable,
        'The prescription image is unreadable or does not contain prescription content.',
      );
    }

    final schemaVersion = decoded['schema_version'] as int? ?? 1;
    final doctorName = decoded['doctor_name'] as String?;
    final patientName = decoded['patient_name'] as String?;
    final date = decoded['date'] as String?;

    final rawMedicines = decoded['medicines'];
    if (rawMedicines is! List) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.invalidSchema,
        'Missing or invalid "medicines" array in JSON response.',
      );
    }

    final List<PrescriptionItem> validatedItems = [];

    for (var m in rawMedicines) {
      if (m is! Map<String, dynamic>) continue;

      final name = (m['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        // Skip items without a medicine name
        continue;
      }

      final strength = (m['strength'] as String?)?.trim();
      final form = (m['form'] as String?)?.trim();
      final instructions = (m['instructions'] as String?)?.trim();

      int? freq = m['frequency_per_day'] is int
          ? m['frequency_per_day'] as int
          : (m['frequency_per_day'] is num ? (m['frequency_per_day'] as num).toInt() : null);

      int? duration = m['duration_days'] is int
          ? m['duration_days'] as int
          : (m['duration_days'] is num ? (m['duration_days'] as num).toInt() : null);

      var confidence = (m['confidence'] as String?)?.toLowerCase() ?? 'medium';
      if (confidence != 'high' && confidence != 'medium' && confidence != 'low') {
        confidence = 'medium';
      }

      // Suspicious heuristics: lower confidence if outside physiological ranges
      if (freq != null && (freq < 1 || freq > 6)) {
        confidence = 'low';
      }
      if (duration != null && (duration < 1 || duration > 180)) {
        confidence = 'low';
      }

      validatedItems.add(
        PrescriptionItem(
          id: '',
          extractedName: name,
          extractedStrength: strength,
          extractedForm: form,
          extractedFrequencyPerDay: freq,
          extractedDurationDays: duration,
          extractedInstructions: instructions,
          confidence: confidence,
          confirmed: confidence == 'high',
        ),
      );
    }

    if (validatedItems.isEmpty) {
      throw PrescriptionExtractionException(
        PrescriptionErrorType.emptyExtraction,
        'No valid medicines could be extracted from the prescription.',
      );
    }

    return PrescriptionDraft(
      schemaVersion: schemaVersion,
      doctorName: doctorName,
      patientName: patientName,
      date: date,
      medicines: validatedItems,
      rawText: rawContent,
    );
  }
}
