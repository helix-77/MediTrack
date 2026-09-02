import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Configuration for API Keys and External Services.
class ApiConfig {
  /// Safely retrieves OpenRouter API Key from environment (.env file)
  static String get openRouterApiKey {
    try {
      final key = dotenv.env['OPENROUTER_API_KEY'];
      if (key != null && key.isNotEmpty && key != 'YOUR_OPENROUTER_API_KEY_HERE') {
        return key;
      }
    } catch (_) {}
    return '';
  }

  /// OpenRouter API Model (Free Router: https://openrouter.ai/openrouter/free)
  static const String openRouterModel = 'openrouter/free';

  /// Legacy Gemini alias kept for migration compatibility
  @Deprecated('Use openRouterApiKey instead')
  static String get geminiApiKey => openRouterApiKey;
  @Deprecated('Use openRouterModel instead')
  static const String geminiModel = openRouterModel;

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
