import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/services/prescription_ocr_service.dart';

void main() {
  group('PrescriptionOcrResult.toPrescriptionItems Tests', () {
    test('parses tablet with strength and frequency 1+0+1', () {
      final ocrResult = PrescriptionOcrResult(
        rawText: 'Dr. John Doe\nTab Napa 500mg 1+0+1 5 days',
        detectedMedicines: [
          'Tab Napa 500mg 1+0+1',
        ],
      );

      final items = ocrResult.toPrescriptionItems();
      expect(items.length, 1);
      expect(items.first.extractedName, 'Napa');
      expect(items.first.extractedForm, 'tablet');
      expect(items.first.extractedStrength, '500mg');
      expect(items.first.extractedFrequencyPerDay, 2);
      expect(items.first.confirmed, isFalse);
    });

    test('parses capsule with strength and frequency 1-0-1', () {
      final ocrResult = PrescriptionOcrResult(
        rawText: 'Cap Seclo 20mg 1-0-1',
        detectedMedicines: [
          'Cap Seclo 20mg 1-0-1',
        ],
      );

      final items = ocrResult.toPrescriptionItems();
      expect(items.length, 1);
      expect(items.first.extractedName, 'Seclo');
      expect(items.first.extractedForm, 'capsule');
      expect(items.first.extractedStrength, '20mg');
      expect(items.first.extractedFrequencyPerDay, 2);
    });

    test('parses syrup with ml strength and 1-1-1 schedule', () {
      final ocrResult = PrescriptionOcrResult(
        rawText: 'Syrup Tofen 100ml 1-1-1',
        detectedMedicines: [
          'Syrup Tofen 100ml 1-1-1',
        ],
      );

      final items = ocrResult.toPrescriptionItems();
      expect(items.length, 1);
      expect(items.first.extractedName, 'Tofen');
      expect(items.first.extractedForm, 'syrup');
      expect(items.first.extractedStrength, '100ml');
      expect(items.first.extractedFrequencyPerDay, 3);
    });

    test('ignores empty lines gracefully', () {
      final ocrResult = PrescriptionOcrResult(
        rawText: '',
        detectedMedicines: ['  '],
      );

      final items = ocrResult.toPrescriptionItems();
      expect(items.isEmpty, isTrue);
    });
  });
}
