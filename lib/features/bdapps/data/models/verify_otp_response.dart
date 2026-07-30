/// Parsed payload from `POST verify_otp.php`.
class VerifyOtpResponse {
  const VerifyOtpResponse({
    required this.isSuccess,
    this.isSubscribed = false,
    this.subscriptionStatus,
    this.statusCode,
    this.statusDetail,
    this.subscriberId,
    this.version,
    this.error,
  });

  final bool isSuccess;
  final bool isSubscribed;
  final String? subscriptionStatus;
  final String? statusCode;
  final String? statusDetail;
  final String? subscriberId;
  final String? version;
  final String? error;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      isSuccess: json['success'] == true || json['statusCode'] == 'S1000',
      isSubscribed: json['isSubscribed'] == true ||
          json['subscriptionStatus'] == 'REGISTERED',
      subscriptionStatus: json['subscriptionStatus'] as String?,
      statusCode: json['statusCode'] as String?,
      statusDetail: json['statusDetail'] as String?,
      subscriberId: json['subscriberId'] as String?,
      version: json['version'] as String?,
      error: json['error'] as String?,
    );
  }
}
