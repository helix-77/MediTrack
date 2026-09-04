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
  final bool isTrial;

  const QuotaEvaluation({
    required this.isAllowed,
    required this.remaining,
    required this.isSoftCapReached,
    required this.statusMessage,
    this.isTrial = false,
  });

  bool get requiresSubscription => !isAllowed && !isSoftCapReached;
  int get remainingDailyQuota => remaining;
}

class EntitlementGuard {
  static const int paidDailySoftCapCombined = 50;

  /// Free trial lifetime allowances for unsubscribed users
  static const int freePrescriptionScansTotal = 1;
  static const int freeAiMessagesTotal = 3;
  static const int freePriceLookupsTotal = 3;

  /// Evaluates whether a user can perform an action based on their subscription
  /// status and usage counters.
  static QuotaEvaluation evaluate({
    required bool isSubscribed,
    required int aiMessagesToday,
    required int prescriptionScansToday,
    int aiMessagesTotal = 0,
    int prescriptionScansTotal = 0,
    int priceLookupsTotal = 0,
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

    // Unsubscribed Users: Check free trial allowances before gating
    switch (feature) {
      case EntitlementFeature.prescriptionOcr:
        final remaining = freePrescriptionScansTotal - prescriptionScansTotal;
        if (remaining > 0) {
          return QuotaEvaluation(
            isAllowed: true,
            remaining: remaining,
            isSoftCapReached: false,
            statusMessage: 'Free trial ($remaining scan remaining)',
            isTrial: true,
          );
        }
        return const QuotaEvaluation(
          isAllowed: false,
          remaining: 0,
          isSoftCapReached: false,
          statusMessage:
              'Free prescription scan used. Upgrade to MediTrack Premium (৳2.78/day) for unlimited scans.',
        );

      case EntitlementFeature.aiAssistant:
        final remaining = freeAiMessagesTotal - aiMessagesTotal;
        if (remaining > 0) {
          return QuotaEvaluation(
            isAllowed: true,
            remaining: remaining,
            isSoftCapReached: false,
            statusMessage: 'Free trial ($remaining messages remaining)',
            isTrial: true,
          );
        }
        return const QuotaEvaluation(
          isAllowed: false,
          remaining: 0,
          isSoftCapReached: false,
          statusMessage:
              'Free trial limit reached (3/3 messages). Upgrade to MediTrack Premium (৳2.78/day) for unlimited AI assistance.',
        );

      case EntitlementFeature.priceLookup:
        final remaining = freePriceLookupsTotal - priceLookupsTotal;
        if (remaining > 0) {
          return QuotaEvaluation(
            isAllowed: true,
            remaining: remaining,
            isSoftCapReached: false,
            statusMessage: 'Free trial ($remaining lookups remaining)',
            isTrial: true,
          );
        }
        return const QuotaEvaluation(
          isAllowed: false,
          remaining: 0,
          isSoftCapReached: false,
          statusMessage:
              'Free price lookups used (3/3). Upgrade to MediTrack Premium (৳2.78/day) for unlimited price lookups.',
        );

      case EntitlementFeature.nearbyPharmacy:
        return const QuotaEvaluation(
          isAllowed: false,
          remaining: 0,
          isSoftCapReached: false,
          statusMessage:
              'Nearby Pharmacy Search requires MediTrack Premium (৳2.78/day via Robi/Airtel).',
        );
    }
  }
}
