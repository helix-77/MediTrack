/// Parsed response from `POST subscribe.php`.
///
/// Encapsulates the carrier subscription confirmation trigger for Robi / Airtel
/// subscribers via BD Apps.
class SubscribeResponse {
  const SubscribeResponse({
    this.success = false,
    this.subscriberId,
    this.subscriptionStatus,
    this.statusCode,
    this.statusDetail,
    this.error,
    this.version,
  });

  /// `true` when the backend reports success AND the subscription status is
  /// definitively `REGISTERED`.
  final bool success;

  /// Subscriber id formatted as `tel:8801XXXXXXXXX`.
  final String? subscriberId;

  /// Carrier lifecycle status (e.g. `REGISTERED`, `PENDING`, `UNREGISTERED`, `FAILED`, `UNKNOWN`).
  final String? subscriptionStatus;

  /// Application status code from BD Apps (e.g. `S1000`).
  final String? statusCode;

  /// Detailed message from BD Apps or the backend.
  final String? statusDetail;

  /// Transport or validation error description if the request failed.
  final String? error;

  /// API version.
  final String? version;

  /// Helper: whether the carrier has confirmed registration.
  bool get isRegistered => subscriptionStatus?.toUpperCase() == 'REGISTERED';

  /// Helper: whether the carrier confirmation is still pending user USSD response.
  bool get isPending =>
      subscriptionStatus != null &&
      subscriptionStatus!.toUpperCase().contains('PENDING');

  /// Helper: whether the user is successfully subscribed.
  bool get isSubscribed => isRegistered;

  /// Helper: whether the request reached the carrier successfully (even if pending confirmation).
  bool get isRequestAccepted =>
      statusCode == 'S1000' || isPending || isRegistered;

  factory SubscribeResponse.fromJson(Map<String, dynamic> json) {
    return SubscribeResponse(
      success: _parseBool(json['success']) ?? false,
      subscriberId: json['subscriberId'] as String?,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      error: json['error'] as String?,
      version: json['version'] as String?,
    );
  }

  static bool? _parseBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final lower = raw.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }
}
