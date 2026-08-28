enum EntitlementFeature {
  aiAssistant,
  prescriptionOcr,
  priceLookup,
  nearbyPharmacy;

  String get displayName {
    return switch (this) {
      EntitlementFeature.aiAssistant => 'AI Health Assistant',
      EntitlementFeature.prescriptionOcr => 'AI Prescription OCR',
      EntitlementFeature.priceLookup => 'Medicine Price & Generic Lookup',
      EntitlementFeature.nearbyPharmacy => 'Nearby Pharmacy Search',
    };
  }
}

class QuotaEvaluation {
  final bool isAllowed;
  final int remaining;
  final bool isSoftCapReached;
  final String statusMessage;

  const QuotaEvaluation({
    required this.isAllowed,
    required this.remaining,
    required this.isSoftCapReached,
    required this.statusMessage,
  });

  bool get requiresSubscription => !isAllowed && !isSoftCapReached;
  int get remainingDailyQuota => remaining;
}

class EntitlementGuard {
  static const int paidDailySoftCapCombined = 50;

  /// Evaluates whether a user can perform an action based on their subscription
  /// status and daily usage counters.
  static QuotaEvaluation evaluate({
    required bool isSubscribed,
    required int aiMessagesToday,
    required int prescriptionScansToday,
    required EntitlementFeature feature,
  }) {
    if (isSubscribed) {
      if (feature == EntitlementFeature.aiAssistant ||
          feature == EntitlementFeature.prescriptionOcr) {
        final totalCombined = aiMessagesToday + prescriptionScansToday;
        if (totalCombined >= paidDailySoftCapCombined) {
          return const QuotaEvaluation(
            isAllowed: false,
            remaining: 0,
            isSoftCapReached: true,
            statusMessage:
                'Daily premium limit (50 requests) reached. Resets at midnight.',
          );
        }
        final remaining = paidDailySoftCapCombined - totalCombined;
        return QuotaEvaluation(
          isAllowed: true,
          remaining: remaining,
          isSoftCapReached: false,
          statusMessage: 'Premium active ($remaining daily requests remaining)',
        );
      }

      return const QuotaEvaluation(
        isAllowed: true,
        remaining: 999,
        isSoftCapReached: false,
        statusMessage: 'Premium active',
      );
    }

    // Unsubscribed / Free Tier: Gated cost centers are blocked
    final featureName = switch (feature) {
      EntitlementFeature.aiAssistant => 'AI Assistant',
      EntitlementFeature.prescriptionOcr => 'Prescription AI OCR',
      EntitlementFeature.priceLookup => 'Medicine Price & Generic Lookup',
      EntitlementFeature.nearbyPharmacy => 'Nearby Pharmacy Search',
    };

    return QuotaEvaluation(
      isAllowed: false,
      remaining: 0,
      isSoftCapReached: false,
      statusMessage:
          '$featureName requires MediTrack Premium (৳2.99/day via Robi/Airtel).',
    );
  }
}
