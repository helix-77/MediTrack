import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized Configuration for API Keys and External Services.
class ApiConfig {
  /// Safely retrieves OpenRouter API Key from environment (.env file)
  static String get openRouterApiKey {
    try {
      final key = dotenv.env['OPENROUTER_API_KEY'];
      if (key != null &&
          key.isNotEmpty &&
          key != 'YOUR_OPENROUTER_API_KEY_HERE') {
        return key;
      }
    } catch (_) {}
    return '';
  }

  /// OpenRouter API Model (Free Router: https://openrouter.ai/openrouter/free)
  static const String openRouterModel = 'openrouter/free';

  /// Vision-capable free models for AI Assistant chat image attachments.
  ///
  /// Do NOT use [openRouterModel] when an image is attached: it is a meta-router
  /// that may route to a text-only upstream which cannot see the image.
  /// Every entry here was verified via /api/v1/models to accept image input
  /// (architecture.input_modalities includes "image").
  ///
  /// IMPORTANT: keep this list at 3 items or fewer — OpenRouter rejects
  /// requests whose `models` fallback array has more than 3 items.
  static const List<String> openRouterVisionModels = [
    'minimax/minimax-m3:free',
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
  ];

  /// Firebase AI Logic Gemini Model for Prescription OCR extraction.
  static const String geminiModel = 'gemini-3.6-flash';

  /// URL of the authenticated AppsPro Firebase HTTPS proxy.
  ///
  /// This is intentionally the only AppsPro endpoint the Flutter app calls.
  static String get appsProProxyUrl {
    try {
      final url = dotenv.env['APPSPRO_PROXY_URL'];
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (_) {}
    return '';
  }

  /// AppsPro publishable key. This key is safe to include in a client build.
  static String get appsProPublishableKey {
    try {
      final key =
          dotenv.env['APPSPRO_PUBLISHABLE_KEY'] ??
          dotenv.env['Publishable_Key'];
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
}
