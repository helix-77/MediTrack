import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditrack/core/network/openrouter_sanitizing_client.dart';

void main() {
  group('OpenRouterSanitizingHttpClient', () {
    test('strips null-valued keys from JSON request body', () async {
      late Map<String, dynamic> capturedJson;

      final mockInner = MockClient((request) async {
        capturedJson = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"ok": true}', 200);
      });

      final client = OpenRouterSanitizingHttpClient(mockInner);

      await client.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'model': 'openrouter/free',
          'messages': [{'role': 'user', 'content': 'hello'}],
          'debug': null,
          'prediction': null,
          'max_tokens': 1024,
        }),
      );

      expect(capturedJson.containsKey('debug'), isFalse);
      expect(capturedJson.containsKey('prediction'), isFalse);
      expect(capturedJson['model'], 'openrouter/free');
      expect(capturedJson['max_tokens'], 1024);
    });

    test('preserves non-null fields and non-json requests intact', () async {
      late String capturedBody;

      final mockInner = MockClient((request) async {
        capturedBody = request.body;
        return http.Response('{"ok": true}', 200);
      });

      final client = OpenRouterSanitizingHttpClient(mockInner);

      await client.post(
        Uri.parse('https://example.com/other'),
        headers: {'content-type': 'text/plain'},
        body: 'raw body with debug=null',
      );

      expect(capturedBody, 'raw body with debug=null');
    });
  });
}
