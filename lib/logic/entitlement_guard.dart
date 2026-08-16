enum EntitlementFeature {
  aiAssistant,
  prescriptionOcr,
  priceLookup,
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
}

class EntitlementGuard {
  static const int freeDailyAiMessages = 3;
  static const int freeDailyPrescriptions = 1;
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

    // Free Preview Tier
    switch (feature) {
      case EntitlementFeature.aiAssistant:
        if (aiMessagesToday >= freeDailyAiMessages) {
          return const QuotaEvaluation(
            isAllowed: false,
            remaining: 0,
            isSoftCapReached: false,
            statusMessage:
                'Free preview limit reached (3 messages/day). Subscribe via BD Apps for unlimited AI access.',
          );
        }
        final remaining = freeDailyAiMessages - aiMessagesToday;
        return QuotaEvaluation(
          isAllowed: true,
          remaining: remaining,
          isSoftCapReached: false,
          statusMessage: 'Free preview: $remaining of $freeDailyAiMessages daily messages remaining',
        );

      case EntitlementFeature.prescriptionOcr:
        if (prescriptionScansToday >= freeDailyPrescriptions) {
          return const QuotaEvaluation(
            isAllowed: false,
            remaining: 0,
            isSoftCapReached: false,
            statusMessage:
                'Free preview limit reached (1 scan/day). Subscribe via BD Apps for unlimited prescription OCR.',
          );
        }
        final remaining = freeDailyPrescriptions - prescriptionScansToday;
        return QuotaEvaluation(
          isAllowed: true,
          remaining: remaining,
          isSoftCapReached: false,
          statusMessage: 'Free preview: $remaining of $freeDailyPrescriptions daily scans remaining',
        );

      case EntitlementFeature.priceLookup:
        return const QuotaEvaluation(
          isAllowed: true,
          remaining: 999,
          isSoftCapReached: false,
          statusMessage: 'Free reference price lookup',
        );
    }
  }
}
