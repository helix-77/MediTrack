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

    test('parseActionFromContent extracts UPDATE_MEDICINE action', () {
      const rawResponse = '''
I have updated your Napa routine to 25 tablets and updated dose times.

```json
{
  "action": "UPDATE_MEDICINE",
  "medicineId": "med_123",
  "name": "Napa",
  "stock": 25,
  "doseTimes": ["09:00", "21:00"]
}
```
''';

      final action = OpenRouterAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, AiActionType.updateMedicine);
      expect(action.data['name'], 'Napa');
      expect(action.data['medicineId'], 'med_123');
      expect(action.data['stock'], 25);
    });

    test('parseActionFromContent extracts DELETE_MEDICINE action', () {
      const rawResponse = '''
I will remove Seclo from your daily medication schedule.

```json
{
  "action": "DELETE_MEDICINE",
  "medicineId": "med_456",
  "name": "Seclo"
}
```
''';

      final action = OpenRouterAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, AiActionType.deleteMedicine);
      expect(action.data['name'], 'Seclo');
      expect(action.data['medicineId'], 'med_456');
    });

    test('parseActionFromContent extracts UPDATE_BUY_ITEM action', () {
      const rawResponse = '''
Updating Vitamin C quantity to 3 in your buy list.

```json
{
  "action": "UPDATE_BUY_ITEM",
  "itemId": "buy_789",
  "name": "Vitamin C 1000mg",
  "quantity": 3
}
```
''';

      final action = OpenRouterAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, AiActionType.updateBuyItem);
      expect(action.data['name'], 'Vitamin C 1000mg');
      expect(action.data['itemId'], 'buy_789');
      expect(action.data['quantity'], 3);
    });

    test('parseActionFromContent extracts DELETE_BUY_ITEM action', () {
      const rawResponse = '''
Removing Paracetamol from your buy list.

```json
{
  "action": "DELETE_BUY_ITEM",
  "itemId": "buy_101",
  "name": "Paracetamol"
}
```
''';

      final action = OpenRouterAiService.parseActionFromContent(rawResponse);
      expect(action, isNotNull);
      expect(action!.type, AiActionType.deleteBuyItem);
      expect(action.data['name'], 'Paracetamol');
      expect(action.data['itemId'], 'buy_101');
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

    test('buildSystemInstruction formats database instructions', () {
      final prompt = OpenRouterAiService.buildSystemInstruction();
      expect(prompt.contains('DATABASE QUERIES & CRUD INSTRUCTIONS'), isTrue);
      expect(prompt.contains('UPDATE_MEDICINE'), isTrue);
      expect(prompt.contains('DELETE_MEDICINE'), isTrue);
      expect(prompt.contains('UPDATE_BUY_ITEM'), isTrue);
      expect(prompt.contains('DELETE_BUY_ITEM'), isTrue);
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
