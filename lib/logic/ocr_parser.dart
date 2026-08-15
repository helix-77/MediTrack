/// A package-independent line of text returned by an OCR adapter.
class OcrTextLine {
  final String text;
  final double boundingBoxHeight;

  const OcrTextLine({required this.text, required this.boundingBoxHeight});
}

/// The fields that can be safely suggested from a medicine-box scan.
class MedicineBoxOcrResult {
  final String? nameCandidate;
  final DateTime? expiryDate;
  final DateTime? manufactureDate;
  final String? batchNumber;

  const MedicineBoxOcrResult({
    this.nameCandidate,
    this.expiryDate,
    this.manufactureDate,
    this.batchNumber,
  });
}

/// Conservative, deterministic parsing rules for printed medicine labels.
class MedicineBoxOcrParser {
  static final RegExp _expiryLabel = RegExp(
    r'\b(?:exp(?:iry)?(?:\s+date)?|use\s+before)\b',
    caseSensitive: false,
  );
  static final RegExp _manufactureLabel = RegExp(
    r'\b(?:mfg|manufactured|mfd)\b',
    caseSensitive: false,
  );
  static final RegExp _batchLabel = RegExp(
    r'\b(?:batch|lot|b\s*\.?\s*no)\b',
    caseSensitive: false,
  );
  static final RegExp _datePattern = RegExp(
    r'(?<!\d)(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?!\d)|'
    r'(?<!\d)(\d{1,2})[/-](\d{4})(?!\d)',
  );
  static final RegExp _dateOnlyPattern = RegExp(
    r'^\s*\d{1,2}[/-]\d{1,2}(?:[/-]\d{4})?\s*$|'
    r'^\s*\d{1,2}[/-]\d{4}\s*$',
  );
  static final RegExp _batchPattern = RegExp(
    r'\b(?:batch|lot|b\s*\.?\s*no)\b\s*[:.]?\s*'
    r'([A-Za-z0-9]+(?:-[A-Za-z0-9]+)*)',
    caseSensitive: false,
  );

  const MedicineBoxOcrParser._();

  static MedicineBoxOcrResult parse(List<OcrTextLine> lines) {
    final normalizedLines = lines
        .map(
          (line) => OcrTextLine(
            text: line.text.trim(),
            boundingBoxHeight: line.boundingBoxHeight,
          ),
        )
        .where((line) => line.text.isNotEmpty)
        .toList(growable: false);

    return MedicineBoxOcrResult(
      nameCandidate: _findNameCandidate(normalizedLines),
      expiryDate: _findLabeledDate(normalizedLines, _expiryLabel),
      manufactureDate: _findLabeledDate(normalizedLines, _manufactureLabel),
      batchNumber: _findBatchNumber(normalizedLines),
    );
  }

  static DateTime? _findLabeledDate(List<OcrTextLine> lines, RegExp label) {
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (!label.hasMatch(line.text)) continue;

      final candidates = <String>[line.text];
      if (index + 1 < lines.length) {
        candidates.add(lines[index + 1].text);
      }

      for (final candidate in candidates) {
        final date = _parseFirstDate(candidate);
        if (date != null) return date;
      }
    }
    return null;
  }

  static String? _findBatchNumber(List<OcrTextLine> lines) {
    for (final line in lines) {
      final match = _batchPattern.firstMatch(line.text);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _findNameCandidate(List<OcrTextLine> lines) {
    OcrTextLine? candidate;

    for (final line in lines) {
      if (_isMetadataLine(line.text) || _dateOnlyPattern.hasMatch(line.text)) {
        continue;
      }

      if (candidate == null ||
          line.boundingBoxHeight > candidate.boundingBoxHeight) {
        candidate = line;
      }
    }

    return candidate?.text;
  }

  static bool _isMetadataLine(String text) {
    return _expiryLabel.hasMatch(text) ||
        _manufactureLabel.hasMatch(text) ||
        _batchLabel.hasMatch(text);
  }

  static DateTime? _parseFirstDate(String text) {
    for (final match in _datePattern.allMatches(text)) {
      final fullDay = int.tryParse(match.group(1) ?? '');
      final fullMonth = int.tryParse(match.group(2) ?? '');
      final fullYear = int.tryParse(match.group(3) ?? '');
      final monthOnlyMonth = int.tryParse(match.group(4) ?? '');
      final monthOnlyYear = int.tryParse(match.group(5) ?? '');

      final day = fullYear == null ? 1 : fullDay;
      final month = fullYear == null ? monthOnlyMonth : fullMonth;
      final year = fullYear ?? monthOnlyYear;

      if (day == null || month == null || year == null) continue;
      if (year <= 0 || month < 1 || month > 12) continue;

      final lastDayOfMonth = DateTime(year, month + 1, 0).day;
      if (day < 1 || day > lastDayOfMonth) continue;

      return DateTime(year, month, day);
    }
    return null;
  }
}
