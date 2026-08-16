import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/ai_action_validator.dart';
import 'package:meditrack/logic/entitlement_guard.dart';

void main() {
  group('AiActionValidator Tests', () {
    test('validates valid ADD_MEDICINE action', () {
      final json = {
        'action': 'ADD_MEDICINE',
        'name': 'Napa 500mg',
        'dosage': '1 tablet',
        'frequency': '2 times daily',
        'stock': 20,
      };

      final action = AiActionValidator.validate(json);
      expect(action, isNotNull);
      expect(action!.type, ValidatedActionType.addMedicine);
      expect(action.medicineAction!.name, 'Napa 500mg');
      expect(action.medicineAction!.dosage, '1 tablet');
      expect(action.medicineAction!.frequency, '2 times daily');
      expect(action.medicineAction!.stock, 20);
    });

    test('rejects ADD_MEDICINE action with missing or empty name', () {
      final json = {
        'action': 'ADD_MEDICINE',
        'name': '   ',
        'dosage': '500mg',
      };
      final action = AiActionValidator.validate(json);
      expect(action, isNull);
    });

    test('validates valid ADD_BUY_ITEM action', () {
      final json = {
        'action': 'ADD_BUY_ITEM',
        'name': 'Vitamin C 1000mg',
        'quantity': 3,
      };

      final action = AiActionValidator.validate(json);
      expect(action, isNotNull);
      expect(action!.type, ValidatedActionType.addBuyItem);
      expect(action.buyItemAction!.name, 'Vitamin C 1000mg');
      expect(action.buyItemAction!.quantity, 3);
    });

    test('rejects unknown or invalid action format', () {
      final json = {'action': 'RANDOM_COMMAND', 'data': 'value'};
      final action = AiActionValidator.validate(json);
      expect(action, isNull);
    });
  });

  group('EntitlementGuard Tests', () {
    test('free tier allows up to 3 AI messages daily', () {
      final q1 = EntitlementGuard.evaluate(
        isSubscribed: false,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        feature: EntitlementFeature.aiAssistant,
      );
      expect(q1.isAllowed, isTrue);
      expect(q1.remaining, 3);

      final q2 = EntitlementGuard.evaluate(
        isSubscribed: false,
        aiMessagesToday: 2,
        prescriptionScansToday: 0,
        feature: EntitlementFeature.aiAssistant,
      );
      expect(q2.isAllowed, isTrue);
      expect(q2.remaining, 1);

      final q3 = EntitlementGuard.evaluate(
        isSubscribed: false,
        aiMessagesToday: 3,
        prescriptionScansToday: 0,
        feature: EntitlementFeature.aiAssistant,
      );
      expect(q3.isAllowed, isFalse);
      expect(q3.remaining, 0);
      expect(q3.statusMessage, contains('Free preview limit reached'));
    });

    test('free tier allows 1 prescription extraction daily', () {
      final q1 = EntitlementGuard.evaluate(
        isSubscribed: false,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        feature: EntitlementFeature.prescriptionOcr,
      );
      expect(q1.isAllowed, isTrue);
      expect(q1.remaining, 1);

      final q2 = EntitlementGuard.evaluate(
        isSubscribed: false,
        aiMessagesToday: 0,
        prescriptionScansToday: 1,
        feature: EntitlementFeature.prescriptionOcr,
      );
      expect(q2.isAllowed, isFalse);
      expect(q2.remaining, 0);
    });

    test('paid tier allows requests until soft cap of 50 is reached', () {
      final q1 = EntitlementGuard.evaluate(
        isSubscribed: true,
        aiMessagesToday: 20,
        prescriptionScansToday: 10,
        feature: EntitlementFeature.aiAssistant,
      );
      expect(q1.isAllowed, isTrue);
      expect(q1.remaining, 20);

      final q2 = EntitlementGuard.evaluate(
        isSubscribed: true,
        aiMessagesToday: 35,
        prescriptionScansToday: 15,
        feature: EntitlementFeature.aiAssistant,
      );
      expect(q2.isAllowed, isFalse);
      expect(q2.isSoftCapReached, isTrue);
      expect(q2.statusMessage, contains('50 requests'));
    });
  });
}
