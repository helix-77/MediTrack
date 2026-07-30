/// Parsed payload from `POST unsubscribe.php`.
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

  /// `true` only when the backend reports `statusCode == "S1000"`. Single
  /// source of truth for "unsubscribe succeeded" — call sites should not
  /// check the field directly. Use the getter, not the raw field.
  bool get isSuccess => statusCode == 'S1000';

  factory UnsubscribeResponse.fromJson(Map<String, dynamic> json) {
    return UnsubscribeResponse(
      success: _parseBool(json['success']),
      subscriberId: json['subscriberId'] as String?,
      action: json['action'] as String?,
      version: json['version'] as String?,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      rawResponse: json['rawResponse'] as String?,
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
