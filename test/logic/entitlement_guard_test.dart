import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/entitlement_guard.dart';

void main() {
  group('EntitlementGuard Tests', () {
    test('unregistered / unsubscribed users are blocked from all premium features', () {
      final features = [
        EntitlementFeature.aiAssistant,
        EntitlementFeature.prescriptionOcr,
        EntitlementFeature.priceLookup,
        EntitlementFeature.nearbyPharmacy,
      ];

      for (final feature in features) {
        final result = EntitlementGuard.evaluate(
          isSubscribed: false,
          feature: feature,
          aiMessagesToday: 0,
          prescriptionScansToday: 0,
        );

        expect(result.isAllowed, isFalse);
        expect(result.requiresSubscription, isTrue);
        expect(result.statusMessage, contains('requires MediTrack Premium'));
      }
    });

    test('subscribed users are allowed within daily quota', () {
      final result = EntitlementGuard.evaluate(
        isSubscribed: true,
        feature: EntitlementFeature.aiAssistant,
        aiMessagesToday: 5,
        prescriptionScansToday: 5,
      );

      expect(result.isAllowed, isTrue);
      expect(result.requiresSubscription, isFalse);
      expect(result.remainingDailyQuota, 40);
    });

    test('subscribed users are blocked when exceeding soft daily quota of 50', () {
      final result = EntitlementGuard.evaluate(
        isSubscribed: true,
        feature: EntitlementFeature.prescriptionOcr,
        aiMessagesToday: 25,
        prescriptionScansToday: 25,
      );

      expect(result.isAllowed, isFalse);
      expect(result.requiresSubscription, isFalse);
      expect(result.remainingDailyQuota, 0);
      expect(result.statusMessage, contains('Daily premium limit'));
    });

    test('feature labels and display names are populated correctly', () {
      expect(EntitlementFeature.aiAssistant.displayName, 'AI Health Assistant');
      expect(EntitlementFeature.prescriptionOcr.displayName, 'AI Prescription OCR');
      expect(EntitlementFeature.priceLookup.displayName, 'Medicine Price & Generic Lookup');
      expect(EntitlementFeature.nearbyPharmacy.displayName, 'Nearby Pharmacy Search');
    });
  });
}
