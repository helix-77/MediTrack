import 'package:intl/intl.dart';

/// Centralized configuration and copy for MediTrack's BD Apps subscription offer.
class SubscriptionOfferConfig {
  const SubscriptionOfferConfig._();

  /// Daily subscription price in BDT.
  static const double dailyPrice = 2.78;

  /// Tax disclosure suffix required by Bangladesh telco regulations.
  static const String taxSuffix = '+(VAT+SD+SC)';

  /// Auto-renewal disclosure string.
  static const String autoRenewalDisclosure =
      'Auto-renews daily until cancelled. Charge deducted from your Robi / Airtel mobile balance.';

  /// Version tag tracked when user checks consent box.
  static const String consentVersion = 'v1.0';

  /// Primary headline for the offer.
  static const String headline = 'Upgrade to MediTrack Premium';

  /// Subheading.
  static const String subHeadline =
      'Unlock AI-powered prescription scanning, smart assistant, medicine price lookup, and nearby pharmacy directions.';

  /// Formatted daily price using `intl` currency formatter.
  static String get formattedPrice {
    final format = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    return format.format(dailyPrice).trim();
  }

  /// Feature list with icons and descriptions.
  static const List<Map<String, String>> features = [
    {
      'title': 'AI Prescription Extraction',
      'subtitle':
          'Scan handwritten & digital prescriptions with Gemini 3.6 Flash AI',
      'icon': 'document_scanner',
    },
    {
      'title': 'MediTrack AI Assistant',
      'subtitle':
          'Ask health questions, check dosages, and create routines automatically',
      'icon': 'auto_awesome',
    },
    {
      'title': 'Price & Generic Database',
      'subtitle':
          'Search Bangladesh medicine MRPs and discover cheaper generic alternatives',
      'icon': 'search',
    },
    {
      'title': 'Nearby Pharmacy Search',
      'subtitle': 'Locate open pharmacies near you with one-tap directions',
      'icon': 'local_pharmacy',
    },
  ];

  /// Core features included 100% free for all users
  static const List<String> freeForeverFeatures = [
    'Pill schedule & routine dose tracking',
    'In-app dose alarms & notifications (unlimited)',
    'On-device box & strip OCR scanner',
    'Prescription photo vault storage',
    'Low-stock medicine buy list',
  ];

  /// Introductory free trial allowances for unsubscribed users
  static const List<String> freeTrialAllowances = [
    '1 AI Prescription Scan (Gemini Flash)',
    '3 AI Health Assistant Messages',
    '3 Generic Medicine Price Lookups',
  ];

  static const String consentText =
      'I agree to subscribe to MediTrack Premium at $taxSuffix with daily auto-renewal and accept the Terms & Conditions and Privacy Policy.';

  static const String termsAndConditions = '''
MediTrack Premium Subscription Terms & Conditions (BD Apps):

1. Eligibility: Subscription is available exclusively for active Robi and Airtel prepaid and postpaid mobile subscribers in Bangladesh.
2. Pricing & Billing: The service costs ৳2.78 per day (+VAT, SD, and SC). The charge is deducted automatically from your mobile account balance every 24 hours.
3. Auto-Renewal: Your subscription will renew automatically every day until you explicitly cancel or unsubscribe.
4. Cancellation: You can unsubscribe at any time at zero additional cost directly through the Profile tab in MediTrack or by dialing the standard Robi/Airtel BD Apps USSD menu (*213#).
5. Data Privacy & AI Usage: MediTrack AI features are powered by OpenRouter. No personal health records are shared with third parties without your consent.
6. Medical Disclaimer: MediTrack AI suggestions and prescription extractions are for informational assistance only and do not replace certified medical consultation or emergency diagnosis.
''';

  static const String privacyPolicy = '''
MediTrack Privacy & Subscriber Policy:

1. Phone Number Collection: Your Robi / Airtel mobile number is used strictly as a subscriber identifier (subscriberId) for carrier billing and entitlement verification.
2. No SMS Spam: Subscribing to Premium grants in-app feature access. We do not sell your number or send unsolicited promotional SMS.
3. Storage Security: Account credentials and profiles are securely stored under user-scoped Firestore rules with Firebase App Check protection.
4. AI Data Safety: Images sent for prescription OCR and chat prompts are processed in-flight via secure, authenticated OpenRouter channels and are not used for public model training.
''';
}
