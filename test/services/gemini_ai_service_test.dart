import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditrack/services/gemini_ai_service.dart';

void main() {
  group('GeminiAiService Parsing Tests', () {
    test('parseActionFromContent extracts ADD_MEDICINE action', () {
      const rawResponse = '''
I have added Paracetamol for you. Here is the confirmation details.

```json
{
  "action": "ADD_MEDICINE",
  "name": "Paracetamol",
  "dosage": "500mg",
  "frequency": "2 times daily",
  "stock": 30
}
```
''';

      final action = GeminiAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, GeminiActionType.addMedicine);
      expect(action.data['name'], 'Paracetamol');
      expect(action.data['dosage'], '500mg');
    });

    test('parseActionFromContent extracts ADD_BUY_ITEM action', () {
      const rawResponse = '''
Sure! Adding Vitamin C to your buy list.

```json
{
  "action": "ADD_BUY_ITEM",
  "name": "Vitamin C 1000mg",
  "quantity": 2
}
```
''';

      final action = GeminiAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, GeminiActionType.addBuyItem);
      expect(action.data['name'], 'Vitamin C 1000mg');
      expect(action.data['quantity'], 2);
    });

    test('cleanContentText removes JSON code block', () {
      const rawResponse = '''
Sure! Adding Vitamin C to your buy list.

```json
{
  "action": "ADD_BUY_ITEM",
  "name": "Vitamin C 1000mg",
  "quantity": 2
}
```
''';

      final cleaned = GeminiAiService.cleanContentText(rawResponse);
      expect(cleaned, 'Sure! Adding Vitamin C to your buy list.');
    });
  });

  group('GeminiAiService API Tests', () {
    test('sendMessage returns warning when API key is missing', () async {
      final service = GeminiAiService();
      final response = await service.sendMessage(
        history: [],
        userPrompt: 'Hello',
        runtimeApiKey: '',
      );

      expect(response.content, contains('Gemini API Key is not set'));
    });

    test('sendMessage sends POST request to Gemini endpoint and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'));
        expect(request.url.queryParameters['key'], 'TEST_GEMINI_KEY');

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Hello from Gemini AI!'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final service = GeminiAiService(client: mockClient);
      final response = await service.sendMessage(
        history: [],
        userPrompt: 'Hi Gemini',
        runtimeApiKey: 'TEST_GEMINI_KEY',
      );

      expect(response.content, 'Hello from Gemini AI!');
    });
  });
}
