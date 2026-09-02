/// Parsed payload from `POST verify_otp.php`.
class VerifyOtpResponse {
  const VerifyOtpResponse({
    required this.isSuccess,
    this.isSubscribed = false,
    this.subscriptionStatus,
    this.statusCode,
    this.statusDetail,
    this.subscriberId,
    this.localSubscriberId,
    this.version,
    this.error,
  });

  final bool isSuccess;
  final bool isSubscribed;
  final String? subscriptionStatus;
  final String? statusCode;
  final String? statusDetail;
  final String? subscriberId;
  final String? localSubscriberId;
  final String? version;
  final String? error;

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    final rawMap = json['raw'] is Map<String, dynamic>
        ? json['raw'] as Map<String, dynamic>
        : null;

    final subStatus = (json['subscription_status'] as String?) ??
        (json['subscriptionStatus'] as String?) ??
        (rawMap?['subscriptionStatus'] as String?);

    final code = (json['status_code'] as String?) ??
        (json['statusCode'] as String?) ??
        (rawMap?['statusCode'] as String?);

    final detail = (json['status_detail'] as String?) ??
        (json['statusDetail'] as String?) ??
        (rawMap?['statusDetail'] as String?);

    final subId = (json['subscriber_id'] as String?) ??
        (json['subscriberId'] as String?) ??
        (rawMap?['subscriberId'] as String?);

    final localSubId = (json['local_subscriber_id'] as String?) ??
        (json['localSubscriberId'] as String?);

    final isSub = json['isSubscribed'] == true ||
        subStatus?.toUpperCase() == 'REGISTERED';

    final success = json['success'] == true ||
        code == 'S1000' ||
        isSub;

    return VerifyOtpResponse(
      isSuccess: success,
      isSubscribed: isSub,
      subscriptionStatus: subStatus,
      statusCode: code,
      statusDetail: detail,
      subscriberId: subId,
      localSubscriberId: localSubId,
      version: json['version'] as String?,
      error: (json['error'] as String?) ?? (json['message'] as String?),
    );
  }
}
