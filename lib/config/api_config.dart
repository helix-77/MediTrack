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
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-3.6-flash';

  /// AppsPro API Base URL (default: https://api.appspro.dev/api/v1)
  static String get appsProBaseUrl {
    try {
      final url = dotenv.env['Base_URI'];
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (_) {}
    return 'https://api.appspro.dev/api/v1';
  }

  /// AppsPro Server Secret Key (Bearer token for /api/v1/sdk/* endpoints)
  static String get appsProSecretKey {
    try {
      final key = dotenv.env['APPS_PRO_SECRET_KEY'];
      if (key != null && key.isNotEmpty) {
        return key;
      }
    } catch (_) {}
    return '';
  }

  /// AppsPro Publishable Key (for client-side / webSDK / public endpoints)
  static String get appsProPublishableKey {
    try {
      final key = dotenv.env['Publishable_Key'];
      if (key != null && key.isNotEmpty) {
        return key;
      }
    } catch (_) {}
    return '';
  }

  /// AppsPro Hosted Checkout Share URL
  static String get appsProShareUrl {
    try {
      final url = dotenv.env['Share_URL'];
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (_) {}
    return 'https://appspro.dev';
  }

  /// AppsPro Application UUID
  static String get appsProAppId {
    try {
      final appId = dotenv.env['App_ID'];
      if (appId != null && appId.isNotEmpty) {
        return appId;
      }
    } catch (_) {}
    return '';
  }

  /// Legacy BD Apps backend base URL alias pointing to AppsPro base URL.
  static String get bdappsBaseUrl => appsProBaseUrl;
}
