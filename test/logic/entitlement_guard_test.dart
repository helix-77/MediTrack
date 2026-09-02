import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/entitlement_guard.dart';

void main() {
  group('EntitlementGuard Tests', () {
    test('unsubscribed users get free trial quotas for AI scan, AI messages, and price lookups', () {
      // 1. Prescription OCR trial (1 total)
      final rxFresh = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.prescriptionOcr,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        prescriptionScansTotal: 0,
      );
      expect(rxFresh.isAllowed, isTrue);
      expect(rxFresh.remaining, 1);
      expect(rxFresh.isTrial, isTrue);

      final rxUsed = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.prescriptionOcr,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        prescriptionScansTotal: 1,
      );
      expect(rxUsed.isAllowed, isFalse);
      expect(rxUsed.remaining, 0);
      expect(rxUsed.requiresSubscription, isTrue);
      expect(rxUsed.statusMessage, contains('Free prescription scan used'));

      // 2. AI Assistant trial (3 total)
      final aiFresh = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.aiAssistant,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        aiMessagesTotal: 0,
      );
      expect(aiFresh.isAllowed, isTrue);
      expect(aiFresh.remaining, 3);
      expect(aiFresh.isTrial, isTrue);

      final aiPartial = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.aiAssistant,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        aiMessagesTotal: 2,
      );
      expect(aiPartial.isAllowed, isTrue);
      expect(aiPartial.remaining, 1);

      final aiUsed = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.aiAssistant,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        aiMessagesTotal: 3,
      );
      expect(aiUsed.isAllowed, isFalse);
      expect(aiUsed.remaining, 0);
      expect(aiUsed.requiresSubscription, isTrue);
      expect(aiUsed.statusMessage, contains('Free trial limit reached'));

      // 3. Price Lookup trial (3 total)
      final priceFresh = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.priceLookup,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        priceLookupsTotal: 0,
      );
      expect(priceFresh.isAllowed, isTrue);
      expect(priceFresh.remaining, 3);
      expect(priceFresh.isTrial, isTrue);

      final priceUsed = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.priceLookup,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
        priceLookupsTotal: 3,
      );
      expect(priceUsed.isAllowed, isFalse);
      expect(priceUsed.remaining, 0);
      expect(priceUsed.requiresSubscription, isTrue);
      expect(priceUsed.statusMessage, contains('Free price lookups used'));

      // 4. Nearby pharmacy always requires subscription
      final pharmacy = EntitlementGuard.evaluate(
        isSubscribed: false,
        feature: EntitlementFeature.nearbyPharmacy,
        aiMessagesToday: 0,
        prescriptionScansToday: 0,
      );
      expect(pharmacy.isAllowed, isFalse);
      expect(pharmacy.requiresSubscription, isTrue);
      expect(pharmacy.statusMessage, contains('requires MediTrack Premium'));
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
