/// Parsed payload from `POST sms.php`.
///
/// MediTrack's `sms.php` is a MO/MT gateway: when the carrier pushes an
/// inbound SMS, the gateway logs it and fires a MT acknowledgement back to
/// the sender. The Flutter client uses the same endpoint as a "send a test
/// SMS" trigger by POSTing a message body — the response carries the
/// echoed address and a status string so the UI can confirm the round-trip.
class SendSmsResponse {
  const SendSmsResponse({
    this.success = false,
    this.address,
    this.message,
    this.statusCode,
    this.statusDetail,
    this.error,
  });

  /// Whether the gateway accepted the message. PHP returns `1`/`0` rather
  /// than `true`/`false`, so this is parsed tolerantly.
  final bool success;

  /// The address the gateway echoed (the address the MT reply was sent to).
  final String? address;

  /// The message body echoed back by the gateway (MT acknowledgement).
  final String? message;

  /// Application-defined status code (e.g. `"S1000"`).
  final String? statusCode;

  /// Long-form status description.
  final String? statusDetail;

  /// Set when the request failed at the transport layer (e.g. PHP not
  /// deployed). `null` on a normal response.
  final String? error;

  bool get isSuccess => success || statusCode == 'S1000';

  factory SendSmsResponse.fromJson(Map<String, dynamic> json) {
    return SendSmsResponse(
      success: _parseBool(json['success']) ?? false,
      address: json['address'] as String?,
      message: json['message'] as String?,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      error: json['error'] as String?,
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
