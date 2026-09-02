import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/prescription_extraction.dart';

class PrescriptionOcrResult {
  final String rawText;
  final List<String> detectedMedicines;

  PrescriptionOcrResult({
    required this.rawText,
    required this.detectedMedicines,
  });

  /// Converts detected medicine lines from on-device OCR into [PrescriptionItem] models
  /// for graceful fallback review when AI cloud parsing fails or is uncertain.
  List<PrescriptionItem> toPrescriptionItems() {
    final List<PrescriptionItem> items = [];
    for (final line in detectedMedicines) {
      final parsed = _parseMedicineLine(line);
      if (parsed != null) {
        items.add(parsed);
      }
    }
    return items;
  }

  static PrescriptionItem? _parseMedicineLine(String line) {
    var text = line.trim();
    if (text.isEmpty) return null;

    // Detect form (tab, cap, syrup, drop, inj, etc.)
    String form = 'tablet';
    final formMatch = RegExp(
      r'\b(tab|tablet|cap|capsule|syr|syrup|inj|injection|drop|drops|cream|gel|ointment)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (formMatch != null) {
      final rawForm = formMatch.group(0)!.toLowerCase();
      if (rawForm.startsWith('tab')) {
        form = 'tablet';
      } else if (rawForm.startsWith('cap')) {
        form = 'capsule';
      } else if (rawForm.startsWith('syr')) {
        form = 'syrup';
      } else if (rawForm.startsWith('inj')) {
        form = 'injection';
      } else if (rawForm.startsWith('drop')) {
        form = 'drops';
      } else if (rawForm.startsWith('cream')) {
        form = 'cream';
      } else if (rawForm.startsWith('gel')) {
        form = 'gel';
      } else if (rawForm.startsWith('oint')) {
        form = 'ointment';
      }
    }

    // Detect strength (e.g. 500mg, 20 mg, 1gm, 5ml, 650 mg)
    String? strength;
    final strengthMatch = RegExp(
      r'(\d+(?:\.\d+)?\s*(?:mg|gm|g|ml|mcg|iu))\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (strengthMatch != null) {
      strength = strengthMatch.group(0);
    }

    // Detect frequency schedule (e.g. 1+0+1, 1-0-1, 1+1+1, 1-1-1, 1-0-0, 0-0-1)
    int? frequency;
    final freqMatch = RegExp(r'\b([012])[\+\-]([012])[\+\-]([012])\b').firstMatch(text);
    if (freqMatch != null) {
      final m1 = int.tryParse(freqMatch.group(1)!) ?? 0;
      final m2 = int.tryParse(freqMatch.group(2)!) ?? 0;
      final m3 = int.tryParse(freqMatch.group(3)!) ?? 0;
      final sum = m1 + m2 + m3;
      frequency = sum > 0 ? sum : null;
    }

    // Strip tab/cap prefix, strength, and schedule to extract cleaner brand name
    var name = text;
    name = name.replaceAll(
      RegExp(
        r'\b(tablet|tab|capsule|cap|syrup|syr|injection|inj|drops|drop|cream|gel|ointment|oint|rx|r\/x)\.?\s*',
        caseSensitive: false,
      ),
      '',
    );
    if (strength != null) {
      name = name.replaceAll(strength, '');
    }
    if (freqMatch != null) {
      name = name.replaceAll(freqMatch.group(0)!, '');
    }

    // Clean any leading/trailing symbols
    name = name.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '').trim();
    if (name.isEmpty) name = text;

    return PrescriptionItem(
      id: '',
      extractedName: name,
      extractedStrength: strength,
      extractedForm: form,
      extractedFrequencyPerDay: frequency ?? 2,
      extractedDurationDays: 7,
      confidence: 'medium',
      confirmed: false,
    );
  }
}

class PrescriptionOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<PrescriptionOcrResult> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final String rawText = recognizedText.text;
    final List<String> detectedMedicines = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final text = line.text.trim();
        if (_isLikelyMedicineLine(text)) {
          if (!detectedMedicines.contains(text)) {
            detectedMedicines.add(text);
          }
        }
      }
    }

    return PrescriptionOcrResult(
      rawText: rawText,
      detectedMedicines: detectedMedicines,
    );
  }

  bool _isLikelyMedicineLine(String line) {
    if (line.length < 3) return false;
    final lower = line.toLowerCase();

    // Exclude header words
    if (lower.contains('doctor') ||
        lower.contains('hospital') ||
        lower.contains('patient') ||
        lower.contains('signature') ||
        lower.contains('date') ||
        lower.contains('clinic')) {
      return false;
    }

    // Common medicine indicators
    if (lower.contains('mg') ||
        lower.contains('ml') ||
        lower.contains('tab') ||
        lower.contains('cap') ||
        lower.contains('syrup') ||
        lower.contains('daily') ||
        lower.contains('dose') ||
        lower.contains('1-0-1') ||
        lower.contains('1-1-1') ||
        lower.contains('0-0-1') ||
        lower.contains('1+0+1') ||
        lower.contains('1+1+1') ||
        lower.contains('0+0+1') ||
        lower.contains('1+0+0') ||
        lower.contains('1-0-0')) {
      return true;
    }

    return false;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
