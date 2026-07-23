/// Configuration holder for BDApps TAP API credentials and base URL.
class BdAppsConfig {
  final String applicationId;
  final String password;
  final String baseUrl;

  const BdAppsConfig({
    required this.applicationId,
    required this.password,
    this.baseUrl = 'https://api.bdapps.com',
  });
}

/// Base response returned by BDApps TAP APIs.
class BdAppsResponse {
  final String? version;
  final String statusCode;
  final String statusDetail;

  BdAppsResponse({
    this.version,
    required this.statusCode,
    required this.statusDetail,
  });

  /// Returns true if status code indicates success (`S1000`).
  bool get isSuccess => statusCode == 'S1000';

  factory BdAppsResponse.fromJson(Map<String, dynamic> json) {
    return BdAppsResponse(
      version: json['version'] as String?,
      statusCode: (json['statusCode'] as String?) ?? 'E1000',
      statusDetail: (json['statusDetail'] as String?) ?? 'Unknown response',
    );
  }
}

/// Response model returned from `/otp/request`.
class BdAppsOtpResponse extends BdAppsResponse {
  final String? referenceNo;

  BdAppsOtpResponse({
    super.version,
    required super.statusCode,
    required super.statusDetail,
    this.referenceNo,
  });

  factory BdAppsOtpResponse.fromJson(Map<String, dynamic> json) {
    return BdAppsOtpResponse(
      version: json['version'] as String?,
      statusCode: (json['statusCode'] as String?) ?? 'E1000',
      statusDetail: (json['statusDetail'] as String?) ?? 'Unknown response',
      referenceNo: json['referenceNo'] as String?,
    );
  }
}

/// Response model returned from `/otp/verify`.
class BdAppsOtpVerifyResponse extends BdAppsResponse {
  final String? subscriptionStatus;
  final String? subscriberId;

  BdAppsOtpVerifyResponse({
    super.version,
    required super.statusCode,
    required super.statusDetail,
    this.subscriptionStatus,
    this.subscriberId,
  });

  bool get isRegistered =>
      subscriptionStatus != null &&
      subscriptionStatus!.toUpperCase().startsWith('REGISTERED');

  factory BdAppsOtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    return BdAppsOtpVerifyResponse(
      version: json['version'] as String?,
      statusCode: (json['statusCode'] as String?) ?? 'E1000',
      statusDetail: (json['statusDetail'] as String?) ?? 'Unknown response',
      subscriptionStatus: json['subscriptionStatus'] as String?,
      subscriberId: json['subscriberId'] as String?,
    );
  }
}

/// Response model returned from `/subscription/subscriberStatus` and `/subscription/userSubscription`.
class BdAppsSubscriptionStatusResponse extends BdAppsResponse {
  final String? subscriptionStatus;

  BdAppsSubscriptionStatusResponse({
    super.version,
    required super.statusCode,
    required super.statusDetail,
    this.subscriptionStatus,
  });

  bool get isRegistered =>
      subscriptionStatus != null &&
      subscriptionStatus!.toUpperCase().startsWith('REGISTERED');

  factory BdAppsSubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    return BdAppsSubscriptionStatusResponse(
      version: json['version'] as String?,
      statusCode: (json['statusCode'] as String?) ?? 'E1000',
      statusDetail: (json['statusDetail'] as String?) ?? 'Unknown response',
      subscriptionStatus: json['subscriptionStatus'] as String?,
    );
  }
}
