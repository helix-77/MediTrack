import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../firebase_options.dart';
import '../config/api_config.dart';

/// Service for analyzing prescriptions and medicine labels using Firebase AI Logic.
class AIPrescriptionService {
  GenerativeModel? _model;

  /// Initializes Firebase and the Firebase AI Logic GenerativeModel.
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Initialize Gemini Developer API using the centralized model configuration.
    _model = FirebaseAI.googleAI().generativeModel(
      model: ApiConfig.geminiModel,
    );
  }

  /// Analyzes a prescription image or medicine label provided as raw bytes.
  ///
  /// [imageBytes] is the image byte data.
  /// [mimeType] is the MIME type of the image (e.g., 'image/jpeg', 'image/png').
  /// [promptText] optional custom prompt text for analysis.
  Future<String?> analyzePrescription({
    required Uint8List imageBytes,
    required String mimeType,
    String? promptText,
  }) async {
    if (_model == null) {
      await initialize();
    }

    final defaultPrompt = TextPart(
      promptText ??
          'Analyze this prescription image or medicine label. Extract the medicine name, dosage, frequency, and any special instructions.',
    );

    final imagePart = InlineDataPart(mimeType, imageBytes);

    final response = await _model!.generateContent([
      Content.multi([defaultPrompt, imagePart]),
    ]);

    return response.text;
  }
}
