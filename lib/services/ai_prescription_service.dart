import 'dart:convert';
import 'dart:typed_data';
import 'package:openrouter/openrouter.dart';

import '../config/api_config.dart';

/// Legacy service for analyzing prescriptions and medicine labels using OpenRouter.
/// For structured OCR extraction, use [PrescriptionExtractionService] instead.
class AIPrescriptionService {
  OpenRouterClient? _client;

  Future<void> initialize() async {
    _client ??= OpenRouterClient(apiKey: ApiConfig.openRouterApiKey);
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
    await initialize();

    final base64Image = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Image';

    final text = promptText ??
        'Analyze this prescription image or medicine label. Extract the medicine name, dosage, frequency, and any special instructions.';

    final request = ChatRequest(
      model: ApiConfig.openRouterModel,
      messages: [
        Message(
          role: MessageRole.user,
          content: [
            TextContentItem(text: text),
            ImageContentItem(
              imageUrl: ImageUrl(url: dataUri),
            ),
          ],
        ),
      ],
    );

    final response = await _client!.chatCompletion(request);
    return response.content;
  }
}
