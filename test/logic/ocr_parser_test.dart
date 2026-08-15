import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/ocr_parser.dart';

void main() {
  group('MedicineBoxOcrParser', () {
    test('parses all supported expiry date formats', () {
      final dayMonthYearSlash = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'EXP 25/12/2027', boundingBoxHeight: 10),
      ]);
      final dayMonthYearHyphen = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'EXP 25-12-2027', boundingBoxHeight: 10),
      ]);
      final monthYearSlash = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'EXP 06/2028', boundingBoxHeight: 10),
      ]);
      final monthYearHyphen = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'Expiry', boundingBoxHeight: 10),
        const OcrTextLine(text: '06-2028', boundingBoxHeight: 8),
      ]);

      expect(dayMonthYearSlash.expiryDate, DateTime(2027, 12, 25));
      expect(dayMonthYearHyphen.expiryDate, DateTime(2027, 12, 25));
      expect(monthYearSlash.expiryDate, DateTime(2028, 6));
      expect(monthYearHyphen.expiryDate, DateTime(2028, 6));
    });

    test('parses manufacture date from the following line', () {
      final result = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'MFD', boundingBoxHeight: 10),
        const OcrTextLine(text: '01/2026', boundingBoxHeight: 8),
      ]);

      expect(result.manufactureDate, DateTime(2026, 1));
    });

    test('rejects invalid calendar dates', () {
      final result = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'EXP 31/02/2027', boundingBoxHeight: 10),
      ]);

      expect(result.expiryDate, isNull);
    });

    test('does not treat unrelated dates as expiry', () {
      final result = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'Paracetamol 500 mg', boundingBoxHeight: 20),
        const OcrTextLine(text: '12/2027', boundingBoxHeight: 10),
      ]);

      expect(result.expiryDate, isNull);
    });

    test('parses batch, b.no, and lot labels', () {
      expect(
        MedicineBoxOcrParser.parse([
          const OcrTextLine(text: 'Batch: ABC-123', boundingBoxHeight: 10),
        ]).batchNumber,
        'ABC-123',
      );
      expect(
        MedicineBoxOcrParser.parse([
          const OcrTextLine(text: 'B.No. XY99', boundingBoxHeight: 10),
        ]).batchNumber,
        'XY99',
      );
      expect(
        MedicineBoxOcrParser.parse([
          const OcrTextLine(text: 'Lot: LOT-7', boundingBoxHeight: 10),
        ]).batchNumber,
        'LOT-7',
      );
    });

    test('selects the tallest non-metadata line as the name', () {
      final result = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'EXP 12/2027', boundingBoxHeight: 40),
        const OcrTextLine(text: 'Small text', boundingBoxHeight: 12),
        const OcrTextLine(text: 'AMOXICILLIN 500 MG', boundingBoxHeight: 24),
        const OcrTextLine(text: 'Batch: ABC', boundingBoxHeight: 50),
      ]);

      expect(result.nameCandidate, 'AMOXICILLIN 500 MG');
    });

    test('uses OCR order to break equal-height name ties', () {
      final result = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: 'First candidate', boundingBoxHeight: 20),
        const OcrTextLine(text: 'Second candidate', boundingBoxHeight: 20),
      ]);

      expect(result.nameCandidate, 'First candidate');
    });

    test('returns empty fields for empty or whitespace-only input', () {
      final result = MedicineBoxOcrParser.parse([
        const OcrTextLine(text: '  ', boundingBoxHeight: 20),
      ]);

      expect(result.nameCandidate, isNull);
      expect(result.expiryDate, isNull);
      expect(result.manufactureDate, isNull);
      expect(result.batchNumber, isNull);
    });
  });
}
