import 'dart:convert';
import 'package:http/http.dart' as http;

/// An [http.Client] wrapper that removes null-valued keys from JSON request bodies.
/// This prevents OpenRouter from rejecting requests when optional fields like "debug"
/// are serialized as null by package:openrouter models.
class OpenRouterSanitizingHttpClient extends http.BaseClient {
  final http.Client _inner;

  OpenRouterSanitizingHttpClient([http.Client? inner])
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request &&
        (request.headers['content-type']?.contains('application/json') ?? false)) {
      try {
        final decoded = jsonDecode(request.body);
        if (decoded is Map<String, dynamic>) {
          // Remove keys whose values are null (e.g. "debug": null, "provider": null, etc.)
          decoded.removeWhere((key, value) => value == null);
          request.body = jsonEncode(decoded);
          request.headers['content-length'] =
              utf8.encode(request.body).length.toString();
        }
      } catch (_) {}
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
