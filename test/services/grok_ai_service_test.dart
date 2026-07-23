import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditrack/services/grok_ai_service.dart';

void main() {
  group('GrokAiService Parsing Tests', () {
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

      final action = GrokAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, GrokActionType.addMedicine);
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

      final action = GrokAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, GrokActionType.addBuyItem);
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

      final cleaned = GrokAiService.cleanContentText(rawResponse);
      expect(cleaned, 'Sure! Adding Vitamin C to your buy list.');
    });
  });

  group('GrokAiService API Tests', () {
    test('sendMessage returns warning when API key is missing', () async {
      final service = GrokAiService();
      final response = await service.sendMessage(
        history: [],
        userPrompt: 'Hello',
        runtimeApiKey: '',
      );

      expect(response.content, contains('Grok API Key is not set'));
    });

    test('sendMessage sends POST request with Bearer authorization and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.x.ai/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer TEST_KEY_123');

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Hello from Grok AI!'
                }
              }
            ]
          }),
          200,
        );
      });

      final service = GrokAiService(client: mockClient);
      final response = await service.sendMessage(
        history: [],
        userPrompt: 'Hi Grok',
        runtimeApiKey: 'TEST_KEY_123',
      );

      expect(response.content, 'Hello from Grok AI!');
    });
  });
}
