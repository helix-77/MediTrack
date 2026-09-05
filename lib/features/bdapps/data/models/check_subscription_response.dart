import 'dart:convert';

/// Parsed payload from `POST check_subscription.php` or `POST /sdk/status`.
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
  bool get isSuccess =>
      statusCode == 'S1000' ||
      isSubscribed ||
      subscriptionStatus?.toUpperCase() == 'UNREGISTERED' ||
      error == null;

  factory CheckSubscriptionResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? rawMap;
    if (json['raw'] is Map<String, dynamic>) {
      rawMap = json['raw'] as Map<String, dynamic>;
    } else if (json['raw'] is String) {
      try {
        final decoded = jsonDecode(json['raw'] as String);
        if (decoded is Map<String, dynamic>) {
          rawMap = decoded;
        }
      } catch (_) {}
    }

    final subscriberMap = json['subscriber'] is Map<String, dynamic>
        ? json['subscriber'] as Map<String, dynamic>
        : null;

    final code =
        (json['status_code'] as String?) ??
        (json['statusCode'] as String?) ??
        (rawMap?['statusCode'] as String?) ??
        (rawMap?['status_code'] as String?);

    final detail =
        (json['status_detail'] as String?) ??
        (json['statusDetail'] as String?) ??
        (rawMap?['statusDetail'] as String?) ??
        (rawMap?['status_detail'] as String?);

    final subStatus =
        (json['subscription_status'] as String?) ??
        (json['subscriptionStatus'] as String?) ??
        (subscriberMap?['status'] as String?) ??
        (rawMap?['subscriptionStatus'] as String?) ??
        (rawMap?['subscription_status'] as String?);

    final isValid = json['valid'] == true;

    final isAlreadyActiveSubscriber =
        (subStatus?.toUpperCase() == 'REGISTERED' ||
        subStatus?.toUpperCase() == 'ACTIVE' ||
        subscriberMap?['status']?.toString().toUpperCase() == 'ACTIVE' ||
        isValid == true);

    final isExplicitUnregistered = subStatus?.toUpperCase() == 'UNREGISTERED';

    final normalizedStatus = isAlreadyActiveSubscriber
        ? 'REGISTERED'
        : (isExplicitUnregistered ? 'UNREGISTERED' : subStatus);

    final subId =
        (json['subscriber_id'] as String?) ??
        (json['subscriberId'] as String?) ??
        (subscriberMap?['bdapps_subscriber_id'] as String?) ??
        (rawMap?['subscriberId'] as String?) ??
        (rawMap?['subscriber_id'] as String?);

    final isSub =
        isAlreadyActiveSubscriber ||
        (_parseBool(json['isSubscribed']) ?? false);

    final errorMessage = code == 'E1951' && !isExplicitUnregistered
        ? 'Carrier address format invalid for direct query (E1951: Masked privacy address)'
        : ((json['error'] as String?) ?? (json['reason'] as String?));

    return CheckSubscriptionResponse(
      subscriptionStatus: normalizedStatus,
      isSubscribed: isSub,
      statusCode: code,
      statusDetail: detail,
      version: json['version'] as String?,
      subscriberId: subId,
      error: errorMessage,
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
