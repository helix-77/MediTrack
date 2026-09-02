import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/prescription_validator.dart';
import 'package:meditrack/logic/image_preflight.dart';

void main() {
  group('PrescriptionValidator Tests', () {
    test('parses valid structured JSON extraction', () {
      const jsonResponse = '''
      {
        "schema_version": 1,
        "doctor_name": "Dr. Rafiqul Islam",
        "patient_name": "Ahmed",
        "date": "2026-08-15",
        "medicines": [
          {
            "name": "Napa Extra",
            "strength": "500mg+65mg",
            "form": "tablet",
            "frequency_per_day": 3,
            "duration_days": 7,
            "instructions": "after food",
            "confidence": "high"
          },
          {
            "name": "Seclo",
            "strength": "20 mg",
            "form": "capsule",
            "frequency_per_day": 2,
            "duration_days": 14,
            "instructions": "before meal",
            "confidence": "medium"
          }
        ]
      }
      ''';

      final draft = PrescriptionValidator.parseAndValidate(jsonResponse);
      expect(draft.doctorName, 'Dr. Rafiqul Islam');
      expect(draft.patientName, 'Ahmed');
      expect(draft.date, '2026-08-15');
      expect(draft.medicines.length, 2);

      final napa = draft.medicines[0];
      expect(napa.extractedName, 'Napa Extra');
      expect(napa.extractedStrength, '500mg+65mg');
      expect(napa.extractedFrequencyPerDay, 3);
      expect(napa.confidence, 'high');
      expect(napa.confirmed, isTrue);

      final seclo = draft.medicines[1];
      expect(seclo.extractedName, 'Seclo');
      expect(seclo.confidence, 'medium');
      expect(seclo.confirmed, isFalse);
    });

    test('lowers confidence for out-of-range frequency or duration', () {
      const jsonWithOddFrequency = '''
      {
        "schema_version": 1,
        "medicines": [
          {
            "name": "Extreme Med",
            "frequency_per_day": 12,
            "duration_days": 500,
            "confidence": "high"
          }
        ]
      }
      ''';

      final draft = PrescriptionValidator.parseAndValidate(jsonWithOddFrequency);
      expect(draft.medicines.length, 1);
      expect(draft.medicines[0].confidence, 'low');
      expect(draft.medicines[0].confirmed, isFalse);
    });

    test('throws unreadable exception when model returns error', () {
      const jsonError = '{"error": "unreadable"}';
      expect(
        () => PrescriptionValidator.parseAndValidate(jsonError),
        throwsA(isA<PrescriptionExtractionException>().having(
          (e) => e.type,
          'type',
          PrescriptionErrorType.unreadable,
        )),
      );
    });

    test('throws malformedJson for invalid JSON', () {
      const badJson = 'this is not json { [';
      expect(
        () => PrescriptionValidator.parseAndValidate(badJson),
        throwsA(isA<PrescriptionExtractionException>().having(
          (e) => e.type,
          'type',
          PrescriptionErrorType.malformedJson,
        )),
      );
    });

    test('cleans markdown code fences', () {
      const fenceJson = '```json\n{"schema_version":1,"medicines":[{"name":"Ace"}]}\n```';
      final draft = PrescriptionValidator.parseAndValidate(fenceJson);
      expect(draft.medicines.length, 1);
      expect(draft.medicines[0].extractedName, 'Ace');
    });

    test('returns valid draft with empty medicines when medicines array is empty', () {
      const emptyJson = '''
      {
        "schema_version": 1,
        "doctor_name": "Dr. Karim",
        "date": "2026-09-01",
        "medicines": []
      }
      ''';
      final draft = PrescriptionValidator.parseAndValidate(emptyJson);
      expect(draft.doctorName, 'Dr. Karim');
      expect(draft.date, '2026-09-01');
      expect(draft.medicines, isEmpty);
    });

    test('cleans thinking tags and conversational preambles', () {
      const thinkingJson = '''
      <think>
      The user wants to extract medicines. Napa is visible.
      </think>
      Here is the extracted prescription:
      ```json
      {
        "doctor_name": "Dr. Hasan",
        "medicines": [{"name": "Napa", "strength": "500mg"}]
      }
      ```
      Hope this helps!
      ''';
      final draft = PrescriptionValidator.parseAndValidate(thinkingJson);
      expect(draft.doctorName, 'Dr. Hasan');
      expect(draft.medicines.length, 1);
      expect(draft.medicines.first.extractedName, 'Napa');
    });
  });

  group('ImagePreflight Tests', () {
    test('rejects files smaller than minimum threshold', () {
      final res = ImagePreflight.evaluate(fileSizeBytes: 200);
      expect(res.isAcceptable, isFalse);
      expect(res.warningMessage, contains('small or empty'));
    });

    test('accepts standard image sizes', () {
      final res = ImagePreflight.evaluate(fileSizeBytes: 150 * 1024, width: 1200, height: 1600);
      expect(res.isAcceptable, isTrue);
      expect(res.warningMessage, isNull);
    });

    test('warns for low-resolution images', () {
      final res = ImagePreflight.evaluate(fileSizeBytes: 50 * 1024, width: 200, height: 250);
      expect(res.isAcceptable, isTrue);
      expect(res.warningMessage, contains('low (200x250px)'));
    });
  });
}
