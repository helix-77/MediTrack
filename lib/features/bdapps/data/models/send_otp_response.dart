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
