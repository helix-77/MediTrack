import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Configuration for API Keys and External Services.
class ApiConfig {
  /// Safely retrieves Google Gemini API Key from environment (.env file)
  static String get geminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty && key != 'YOUR_GEMINI_API_KEY_HERE') {
        return key;
      }
    } catch (_) {}
    return '';
  }

  /// Gemini API Endpoints & Models
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-2.5-flash';

  /// BD Apps backend base URL — the PHP endpoints under /backend/ are hosted
  /// here. All auth/subscription requests are POSTed to paths under this URL.
  static const String bdappsBaseUrl = 'https://www.bdappsdigitalapps.com/NADB26067/';
}