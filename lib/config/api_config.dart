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

  /// BDApps Backend Server URL (PHP Proxy Server)
  static String get bdAppsServerUrl {
    try {
      final url = dotenv.env['BDAPPS_SERVER_URL'];
      if (url != null && url.trim().isNotEmpty) {
        return url.trim().replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
    return '';
  }

  /// BDApps App ID
  static String get bdAppsAppId {
    try {
      final appId = dotenv.env['BDAPPS_APP_ID'];
      if (appId != null && appId.trim().isNotEmpty) {
        return appId.trim();
      }
    } catch (_) {}
    return 'APP_139363';
  }

  /// BDApps App Password
  static String get bdAppsPassword {
    try {
      final pass = dotenv.env['BDAPPS_PASSWORD'];
      if (pass != null && pass.trim().isNotEmpty) {
        return pass.trim();
      }
    } catch (_) {}
    return 'y0e74fafba35bd80a3e484ca07ab43715';
  }
}
