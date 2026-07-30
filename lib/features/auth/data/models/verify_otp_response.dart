/// Parsed payload from `POST verify_otp.php`.
///
/// Unlike [SendOtpResponse], this endpoint has no `success` flag — success
/// is signal-by-`statusCode`, with `"S1000"` meaning OK. Use [isSuccess]
/// rather than checking the field directly.
class VerifyOtpResponse {
  const VerifyOtpResponse({
    this.version,
    this.statusCode,
    this.subscriptionStatus,
    this.statusDetail,
    this.subscriberId,
    this.referenceNo,
  });

  /// Backend API version reported in the response.
  final String? version;

  /// Application-defined status code. `"S1000"` means success; other
  /// values (e.g. `"E1999"`) are failures. Use [isSuccess].
  final String? statusCode;

  /// Subscription lifecycle state from the backend (e.g. `"REGISTERED"`).
  final String? subscriptionStatus;

  /// Long-form status description (e.g. `"Success"` on S1000, or the
  /// error message on an E* code).
  final String? statusDetail;

  /// Subscriber id the backend keyed the verify to (e.g. `"tel:880..."`).
  /// Strip a leading `"tel:"` prefix when persisting as the local phone
  /// number, since [LocalStorageService] expects the bare BD form.
  final String? subscriberId;

  /// Echo of the request's reference number, when the server returns it.
  final String? referenceNo;

  /// `true` only when the backend reports `statusCode == "S1000"`. Single
  /// source of truth for "verify succeeded" — call sites should not check
  /// the field directly.
  bool get isSuccess => statusCode == 'S1000';

  /// Returns the persisted phone number form: [subscriberId] with any
  /// leading `"tel:"` prefix removed. Returns `null` when no subscriberId
  /// is present.
  String? get persistedPhoneNumber {
    final id = subscriberId;
    if (id == null) return null;
    return id.startsWith('tel:') ? id.substring(4) : id;
  }

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      version: json['version'] as String?,
      statusCode: json['statusCode'] as String?,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      statusDetail: json['statusDetail'] as String?,
      subscriberId: json['subscriberId'] as String?,
      referenceNo: json['referenceNo'] as String?,
    );
  }
}