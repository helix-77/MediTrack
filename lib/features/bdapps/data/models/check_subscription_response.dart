/// Parsed payload from `POST check_subscription.php`.
///
/// Mirrors the JSON shape produced by `check_subscription.php` — a wrapped
/// status object with `subscriptionStatus`, `isSubscribed`, and the
/// underlying BD Apps `statusCode` / `statusDetail`.
class CheckSubscriptionResponse {
  const CheckSubscriptionResponse({
    this.subscriptionStatus,
    this.isSubscribed = false,
    this.statusCode,
    this.statusDetail,
    this.version,
    this.subscriberId,
    this.error,
    this.details,
  });

  /// Normalized lifecycle state — `"REGISTERED"`, `"UNREGISTERED"`, or
  /// `"UNKNOWN"` if the backend didn't return one.
  final String? subscriptionStatus;

  /// `true` when [subscriptionStatus] is `"REGISTERED"`. The PHP backend
  /// already sets this explicitly so we don't recompute it client-side.
  final bool isSubscribed;

  /// Application-defined status code (e.g. `"S1000"`).
  final String? statusCode;

  /// Long-form status description.
  final String? statusDetail;

  /// Backend API version reported in the response.
  final String? version;

  /// Subscriber id the backend keyed the status to (e.g. `"tel:880..."`).
  final String? subscriberId;

  /// Set when the request failed at the transport layer (e.g. invalid
  /// phone). `null` on a normal response.
  final String? error;

  /// Additional details when [error] is present.
  final String? details;

  /// Whether the subscriber is currently in an active / registered state.
  bool get isAlreadyActive {
    final status = (subscriptionStatus ?? '').toUpperCase();
    final detail = (statusDetail ?? '').toLowerCase();
    final err = (error ?? '').toLowerCase();
    return isSubscribed ||
        status == 'REGISTERED' ||
        detail.contains('already register') ||
        err.contains('already register') ||
        detail.contains('already subscribe') ||
        err.contains('already subscribe') ||
        detail.contains('already active') ||
        err.contains('already active');
  }

  /// Whether the response indicates a non-error carrier communication.
  bool get isSuccess => statusCode == 'S1000' || error == null;

  factory CheckSubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return CheckSubscriptionResponse(
      subscriptionStatus: json['subscriptionStatus'] as String?,
      isSubscribed: _parseBool(json['isSubscribed']) ?? false,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      version: json['version'] as String?,
      subscriberId: json['subscriberId'] as String?,
      error: json['error'] as String?,
      details: json['details'] as String?,
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
