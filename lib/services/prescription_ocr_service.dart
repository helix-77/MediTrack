import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PrescriptionOcrResult {
  final String rawText;
  final List<String> detectedMedicines;

  PrescriptionOcrResult({
    required this.rawText,
    required this.detectedMedicines,
  });
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
        lower.contains('0-0-1')) {
      return true;
    }

    return false;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
