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
    final rawMap = json['raw'] is Map<String, dynamic>
        ? json['raw'] as Map<String, dynamic>
        : null;

    final code = (json['status_code'] as String?) ??
        (json['statusCode'] as String?) ??
        (rawMap?['statusCode'] as String?);

    final refNo = (json['reference_no'] as String?) ??
        (json['referenceNo'] as String?) ??
        (rawMap?['referenceNo'] as String?);

    final subId = (json['subscriber_id'] as String?) ??
        (json['subscriberId'] as String?) ??
        (rawMap?['subscriberId'] as String?);

    final detail = (json['status_detail'] as String?) ??
        (json['statusDetail'] as String?) ??
        (rawMap?['statusDetail'] as String?);

    final success = json['success'] == true ||
        code == 'S1000' ||
        (refNo != null && refNo.isNotEmpty);

    return SendOtpResponse(
      isSuccess: success,
      referenceNo: refNo,
      subscriberId: subId,
      statusCode: code,
      statusDetail: detail,
      version: json['version'] as String?,
      error: (json['error'] as String?) ?? (json['message'] as String?),
    );
  }
}
