/// Centralized Configuration for API Keys and External Services.
class ApiConfig {
  /// Paste your Grok (xAI) API Key below:
  static const String grokApiKey = 'PASTE_YOUR_GROK_API_KEY_HERE';

  /// xAI Grok API Endpoints & Models
  static const String grokBaseUrl = 'https://api.x.ai/v1';
  static const String grokTextModel = 'grok-2-latest';
  static const String grokVisionModel = 'grok-2-vision-1212';
}
