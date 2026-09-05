import 'dart:convert';

/// Parsed payload from `POST /sdk/unsubscribe`.
///
/// Doubles as both DTO and UI-facing entity. Mirrors the shape documented
/// by the BD Apps unsubscribe sample response.
class UnsubscribeResponse {
  const UnsubscribeResponse({
    this.success,
    this.subscriberId,
    this.action,
    this.version,
    this.statusCode,
    this.statusDetail,
    this.subscriptionStatus,
    this.rawResponse,
    this.error,
  });

  /// Whether the server accepted the unsubscribe request. Parsed
  /// tolerantly: PHP backends commonly serialize booleans as `1`/`0`
  /// rather than `true`/`false`, so accept either.
  final bool? success;

  /// Subscriber id the backend keyed the unsubscribe to
  /// (e.g. `"tel:8801676667735"`).
  final String? subscriberId;

  /// Server-reported action code (e.g. `"0"` for unsubscribe).
  final String? action;

  /// Backend API version reported in the response.
  final String? version;

  /// Application-defined status code. `"S1000"` means success; other
  /// values are failures. Use [isSuccess] rather than checking the
  /// field directly.
  final String? statusCode;

  /// Long-form status description (e.g. `"Success"` on S1000, or the
  /// error message on an E* code).
  final String? statusDetail;

  /// Subscription lifecycle state after the unsubscribe
  /// (e.g. `"UNREGISTERED"`).
  final String? subscriptionStatus;

  /// Server's raw response string (often a nested JSON blob as a string).
  final String? rawResponse;

  /// Error message if the request failed.
  final String? error;

  /// `true` only when the backend reports `statusCode == "S1000"` or when
  /// AppsPro's raw carrier response explicitly says `UNREGISTERED`.
  bool get isSuccess =>
      statusCode == 'S1000' || success == true || isUnregistered;

  /// Helper: whether the user is confirmed unregistered / cancelled.
  bool get isUnregistered =>
      subscriptionStatus?.toUpperCase() == 'UNREGISTERED';

  /// Helper: whether the carrier rejected direct unregistration due to address format / privacy masking (BDApps E1951).
  bool get isCarrierAddressRejected => statusCode == 'E1951' && !isUnregistered;

  /// Backward-compatible alias for carrier unregistration error
  bool get isAlreadyUnregistered => false;

  factory UnsubscribeResponse.fromJson(Map<String, dynamic> json) {
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
        (rawMap?['subscriptionStatus'] as String?) ??
        (rawMap?['subscription_status'] as String?);

    final subId =
        (json['subscriber_id'] as String?) ??
        (json['subscriberId'] as String?) ??
        (rawMap?['subscriberId'] as String?) ??
        (rawMap?['subscriber_id'] as String?);

    final explicitSuccess = _parseBool(json['success']);
    final isCarrierAddressRejected =
        code == 'E1951' && subStatus?.toUpperCase() != 'UNREGISTERED';

    final isSuccess =
        (explicitSuccess == true ||
            code == 'S1000' ||
            subStatus?.toUpperCase() == 'UNREGISTERED') &&
        !isCarrierAddressRejected;

    final errorMessage = isCarrierAddressRejected
        ? 'Carrier direct unregistration rejected by BDApps (E1951: Masked privacy address). Please cancel via SMS (STOP meditrack to 21213) or USSD (*213#).'
        : ((json['error'] as String?) ??
              (json['message'] as String?) ??
              (isSuccess ? null : detail));

    return UnsubscribeResponse(
      success: isSuccess,
      subscriberId: subId,
      action: json['action'] as String?,
      version: json['version'] as String?,
      statusCode: code,
      statusDetail: detail,
      subscriptionStatus: subStatus ?? (isSuccess ? 'UNREGISTERED' : null),
      rawResponse: json['rawResponse'] as String?,
      error: errorMessage,
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
