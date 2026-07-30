/// Parsed payload from `POST send_otp.php`.
///
/// Doubles as both DTO and UI-facing entity — MediTrack's auth layer is
/// shallow (no separate domain layer), mirroring the reference project's
/// shape. Mirrors the JSON shape documented under the BD Apps OTP request
/// integration.
class SendOtpResponse {
  const SendOtpResponse({
    required this.success,
    this.message,
    this.referenceNo,
    this.statusCode,
    this.statusDetail,
    this.version,
    this.subscriberId,
  });

  /// Whether the server accepted the OTP request.
  ///
  /// Parsed tolerantly: PHP backends commonly serialize booleans as `1`/`0`
  /// rather than `true`/`false`, so accept either.
  final bool success;

  /// Human-readable message from the server (also used as the user-facing
  /// error string on `success == false`).
  final String? message;

  /// Server-issued reference number for the OTP request, if any.
  final String? referenceNo;

  /// Application-defined error code (e.g. `"E1853"` for the
  /// "Maximum number of OTP requests reached" case).
  final String? statusCode;

  /// Long-form error description, when [statusCode] is set.
  final String? statusDetail;

  /// Backend API version reported in the response.
  final String? version;

  /// Subscriber id the backend keyed the request to (e.g. `"tel:880..."`).
  final String? subscriberId;

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      success: _parseBool(json['success']),
      message: json['message'] as String?,
      referenceNo: json['referenceNo'] as String?,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      version: json['version'] as String?,
      subscriberId: json['subscriberId'] as String?,
    );
  }

  static bool _parseBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final lower = raw.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }
}