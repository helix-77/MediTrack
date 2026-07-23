import 'package:flutter_test/flutter_test.dart';
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
}
