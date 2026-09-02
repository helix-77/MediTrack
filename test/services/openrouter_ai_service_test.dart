import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/services/openrouter_ai_service.dart';

void main() {
  group('OpenRouterAiService Parsing & Model Tests', () {
    test('parseActionFromContent extracts ADD_MEDICINE action', () {
      const rawResponse = '''
I have added Napa for you. Here is the confirmation details.

```json
{
  "action": "ADD_MEDICINE",
  "name": "Napa",
  "dosage": "500mg",
  "frequency": "3 times daily",
  "stock": 20
}
```
''';

      final action = OpenRouterAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, AiActionType.addMedicine);
      expect(action.data['name'], 'Napa');
      expect(action.data['dosage'], '500mg');
    });

    test('parseActionFromContent extracts ADD_BUY_ITEM action', () {
      const rawResponse = '''
Sure! Adding Omeprazole to your grocery list.

```json
{
  "action": "ADD_BUY_ITEM",
  "name": "Omeprazole 20mg",
  "quantity": 14
}
```
''';

      final action = OpenRouterAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, AiActionType.addBuyItem);
      expect(action.data['name'], 'Omeprazole 20mg');
      expect(action.data['quantity'], 14);
    });

    test('cleanContentText removes JSON code block', () {
      const rawResponse = '''
Sure! Adding Omeprazole to your grocery list.

```json
{
  "action": "ADD_BUY_ITEM",
  "name": "Omeprazole 20mg",
  "quantity": 14
}
```
''';

      final cleaned = OpenRouterAiService.cleanContentText(rawResponse);
      expect(cleaned, 'Sure! Adding Omeprazole to your grocery list.');
    });

    test('AiChatMessage correctly identifies user and model messages', () {
      final userMsg = AiChatMessage(role: 'user', content: 'Hi');
      final modelMsg = AiChatMessage(role: 'model', content: 'Hello');

      expect(userMsg.isUser, isTrue);
      expect(modelMsg.isUser, isFalse);
    });

    test('Backward compatibility aliases work seamlessly', () {
      final geminiAction = GeminiAction(
        type: GeminiActionType.addMedicine,
        data: {'name': 'Paracetamol'},
      );
      expect(geminiAction.type, AiActionType.addMedicine);

      final geminiMsg = GeminiChatMessage(role: 'user', content: 'Test');
      expect(geminiMsg.isUser, isTrue);
    });
  });
}
