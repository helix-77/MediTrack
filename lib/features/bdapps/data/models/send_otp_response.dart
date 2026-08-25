/// Parsed payload from `POST send_otp.php`.
class SendOtpResponse {
  const SendOtpResponse({
    required this.isSuccess,
    this.referenceNo,
    this.subscriberId,
    this.statusCode,
    this.statusDetail,
    this.version,
    this.error,
  });

  final bool isSuccess;
  final String? referenceNo;
  final String? subscriberId;
  final String? statusCode;
  final String? statusDetail;
  final String? version;
  final String? error;

  /// Helper: whether BD Apps reported the subscriber is already registered.
  bool get isAlreadyRegistered {
    final detail = (statusDetail ?? '').toLowerCase();
    final err = (error ?? '').toLowerCase();
    return detail.contains('already register') ||
        err.contains('already register') ||
        detail.contains('already subscribe') ||
        err.contains('already subscribe') ||
        detail.contains('already active') ||
        err.contains('already active') ||
        detail.contains('already exist') ||
        err.contains('already exist') ||
        statusCode == 'E1351';
  }

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      isSuccess: json['success'] == true || json['statusCode'] == 'S1000',
      referenceNo: json['referenceNo'] as String?,
      subscriberId: json['subscriberId'] as String?,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      version: json['version'] as String?,
      error: (json['error'] as String?) ?? (json['message'] as String?),
    );
  }
}
