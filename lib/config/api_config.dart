import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Configuration for API Keys and External Services.
class ApiConfig {
  /// Safely retrieves Grok (xAI) API Key from environment (.env file)
  static String get grokApiKey {
    try {
      final key = dotenv.env['GROK_API_KEY'];
      if (key != null && key.isNotEmpty && key != 'YOUR_GROK_API_KEY_HERE') {
        return key;
      }
    } catch (_) {}
    return '';
  }

  /// xAI Grok API Endpoints & Models
  static const String grokBaseUrl = 'https://api.x.ai/v1';
  static const String grokTextModel = 'grok-2-latest';
  static const String grokVisionModel = 'grok-2-vision-1212';
}
