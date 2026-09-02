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

  /// Helper: whether the carrier reported that the user is already registered.
  bool get isAlreadyRegistered {
    final detail = (statusDetail ?? '').toLowerCase();
    final err = (error ?? '').toLowerCase();
    return isRegistered ||
        detail.contains('already register') ||
        err.contains('already register') ||
        detail.contains('already subscribe') ||
        err.contains('already subscribe');
  }

  /// Helper: whether the request reached the carrier successfully (even if pending confirmation).
  bool get isRequestAccepted =>
      statusCode == 'S1000' || isPending || isRegistered || isAlreadyRegistered;

  /// Helper: whether the response indicates success.
  bool get isSuccess => success || statusCode == 'S1000';

  factory SubscribeResponse.fromJson(Map<String, dynamic> json) {
    final rawMap = json['raw'] is Map<String, dynamic>
        ? json['raw'] as Map<String, dynamic>
        : null;

    final subStatus = (json['subscription_status'] as String?) ??
        (json['subscriptionStatus'] as String?) ??
        (rawMap?['subscriptionStatus'] as String?);

    final code = (json['status_code'] as String?) ??
        (json['statusCode'] as String?) ??
        (rawMap?['statusCode'] as String?);

    final detail = (json['status_detail'] as String?) ??
        (json['statusDetail'] as String?) ??
        (rawMap?['statusDetail'] as String?);

    final subId = (json['subscriber_id'] as String?) ??
        (json['subscriberId'] as String?) ??
        (rawMap?['subscriberId'] as String?);

    final isRegistered = subStatus?.toUpperCase() == 'REGISTERED';
    final explicitSuccess = _parseBool(json['success']) ?? false;
    final isSuccess = explicitSuccess || (code == 'S1000' && (isRegistered || subStatus != 'FAILED'));

    return SubscribeResponse(
      success: isSuccess,
      subscriberId: subId,
      subscriptionStatus: subStatus,
      statusCode: code,
      statusDetail: detail,
      error: (json['error'] as String?) ?? (json['message'] as String?),
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
