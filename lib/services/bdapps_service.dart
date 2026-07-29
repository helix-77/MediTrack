import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/bdapps_models.dart';

/// Service responsible for communicating with BDApps services.
/// Supports both:
/// 1. **PHP Proxy Server Mode** (via custom backend hosting `send_otp.php`, `verify_otp.php`, `check_subscription.php`, `unsubscribe.php`)
/// 2. **Direct BDApps TAP API Mode** (`https://developer.bdapps.com`)
class BdAppsService {
  final BdAppsConfig config;
  final String? serverUrlOverride;
  final http.Client _client;

  BdAppsService({
    BdAppsConfig? config,
    String? serverUrl,
    http.Client? client,
  })  : config = config ??
            BdAppsConfig(
              applicationId: ApiConfig.bdAppsAppId,
              password: ApiConfig.bdAppsPassword,
            ),
        serverUrlOverride = serverUrl,
        _client = client ?? http.Client();

  /// Gets the effective backend proxy server URL if configured.
  String get effectiveServerUrl {
    if (serverUrlOverride != null && serverUrlOverride!.trim().isNotEmpty) {
      return serverUrlOverride!.trim().replaceAll(RegExp(r'/+$'), '');
    }
    final envUrl = ApiConfig.bdAppsServerUrl;
    if (envUrl.isNotEmpty) {
      return envUrl.replaceAll(RegExp(r'/+$'), '');
    }
    return '';
  }

  /// Whether the service is currently running in PHP Proxy Server Mode.
  bool get isServerProxyMode => effectiveServerUrl.isNotEmpty;

  /// Gets the effective direct BDApps TAP API base URL.
  String get effectiveDirectBaseUrl {
    if (config.baseUrl.startsWith('http') &&
        (config.baseUrl.contains('bdapps.com') ||
            config.baseUrl.contains('developer.bdapps.com'))) {
      return config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    }
    return 'https://developer.bdapps.com';
  }

  /// Formats raw phone number input into BDApps `tel:8801XXXXXXXXX` format.
  static String formatSubscriberId(String rawPhone) {
    final digits = formatLocalMobile(rawPhone);
    return 'tel:88$digits';
  }

  /// Formats raw phone number into standard 11-digit local BD format (`01XXXXXXXXX`).
  static String formatLocalMobile(String rawPhone) {
    String clean = rawPhone.trim().replaceAll(RegExp(r'\s+|-'), '');
    if (clean.startsWith('tel:')) {
      clean = clean.substring(4);
    }
    if (clean.startsWith('+88')) {
      clean = clean.substring(3);
    } else if (clean.startsWith('88')) {
      clean = clean.substring(2);
    }

    if (!clean.startsWith('0') && clean.length == 10) {
      clean = '0$clean';
    }

    return clean;
  }

  /// Request OTP for a subscriber's phone number.
  /// Uses `send_otp.php` when in Server Proxy Mode, or `/otp/request` when in Direct Mode.
  Future<BdAppsOtpResponse> requestOtp({
    required String phoneNumber,
    String applicationHash = 'bdapps',
    Map<String, String>? applicationMetaData,
  }) async {
    final localPhone = formatLocalMobile(phoneNumber);

    if (isServerProxyMode) {
      final url = Uri.parse('$effectiveServerUrl/send_otp.php');
      try {
        final response = await _client.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'user_mobile': localPhone},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final bool success = data['success'] == true;
          final refNo = data['referenceNo'] as String?;
          final statusDetail = (data['message'] ?? data['statusDetail'] ?? '') as String;
          final statusCode = (data['statusCode'] ?? (success ? 'S1000' : 'E500')) as String;

          return BdAppsOtpResponse(
            referenceNo: refNo,
            statusCode: statusCode,
            statusDetail: statusDetail.isNotEmpty ? statusDetail : (success ? 'OTP Sent' : 'Failed to send OTP'),
            version: (data['version'] as String?) ?? '1.0',
          );
        } else {
          return BdAppsOtpResponse(
            statusCode: 'E${response.statusCode}',
            statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        return BdAppsOtpResponse(
          statusCode: 'E500',
          statusDetail: 'Server error: $e',
        );
      }
    }

    // Direct BDApps TAP API Mode
    final url = Uri.parse('$effectiveDirectBaseUrl/otp/request');
    final formattedPhone = formatSubscriberId(phoneNumber);

    final payload = <String, dynamic>{
      'applicationId': config.applicationId,
      'password': config.password,
      'subscriberId': formattedPhone,
      'applicationHash': applicationHash,
      'applicationMetaData': applicationMetaData ??
          {
            'client': 'MOBILEAPP',
            'device': 'Mobile',
            'os': 'Android',
          },
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json;charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return BdAppsOtpResponse.fromJson(data);
      } else {
        return BdAppsOtpResponse(
          statusCode: 'E${response.statusCode}',
          statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return BdAppsOtpResponse(
        statusCode: 'E500',
        statusDetail: 'Network request failed: $e',
      );
    }
  }

  /// Verify OTP provided by subscriber.
  /// Uses `verify_otp.php` when in Server Proxy Mode, or `/otp/verify` when in Direct Mode.
  Future<BdAppsOtpVerifyResponse> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    if (isServerProxyMode) {
      final url = Uri.parse('$effectiveServerUrl/verify_otp.php');
      try {
        final response = await _client.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'referenceNo': referenceNo,
            'Otp': otp,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final statusCode = (data['statusCode'] ?? 'FAILED') as String;
          final statusDetail = (data['statusDetail'] ?? data['message'] ?? '') as String;
          final subscriptionStatus = (data['subscriptionStatus'] ?? '') as String;
          final subscriberId = (data['subscriberId'] ?? '') as String;

          return BdAppsOtpVerifyResponse(
            statusCode: statusCode,
            statusDetail: statusDetail,
            subscriptionStatus: subscriptionStatus,
            subscriberId: subscriberId,
            version: (data['version'] as String?) ?? '1.0',
          );
        } else {
          return BdAppsOtpVerifyResponse(
            statusCode: 'E${response.statusCode}',
            statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        return BdAppsOtpVerifyResponse(
          statusCode: 'E500',
          statusDetail: 'Server error: $e',
        );
      }
    }

    // Direct BDApps TAP API Mode
    final url = Uri.parse('$effectiveDirectBaseUrl/otp/verify');

    final payload = <String, dynamic>{
      'applicationId': config.applicationId,
      'password': config.password,
      'referenceNo': referenceNo,
      'otp': otp,
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json;charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return BdAppsOtpVerifyResponse.fromJson(data);
      } else {
        return BdAppsOtpVerifyResponse(
          statusCode: 'E${response.statusCode}',
          statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return BdAppsOtpVerifyResponse(
        statusCode: 'E500',
        statusDetail: 'Network request failed: $e',
      );
    }
  }

  /// Query subscription status of subscriber MSISDN.
  /// Uses `check_subscription.php` when in Server Proxy Mode, or `/subscription/subscriberStatus` when in Direct Mode.
  Future<BdAppsSubscriptionStatusResponse> checkSubscriptionStatus({
    required String phoneNumber,
  }) async {
    final localPhone = formatLocalMobile(phoneNumber);

    if (isServerProxyMode) {
      final url = Uri.parse('$effectiveServerUrl/check_subscription.php');
      try {
        final response = await _client.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'user_mobile': localPhone},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final subscriptionStatus = (data['subscriptionStatus'] ?? 'UNREGISTERED') as String;
          final statusCode = (data['statusCode'] ?? 'S1000') as String;
          final statusDetail = (data['statusDetail'] ?? '') as String;

          return BdAppsSubscriptionStatusResponse(
            statusCode: statusCode,
            statusDetail: statusDetail,
            subscriptionStatus: subscriptionStatus,
            version: (data['version'] as String?) ?? '1.0',
          );
        } else {
          return BdAppsSubscriptionStatusResponse(
            statusCode: 'E${response.statusCode}',
            statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        return BdAppsSubscriptionStatusResponse(
          statusCode: 'E500',
          statusDetail: 'Server error: $e',
        );
      }
    }

    // Direct BDApps TAP API Mode
    final url = Uri.parse('$effectiveDirectBaseUrl/subscription/subscriberStatus');
    final formattedPhone = formatSubscriberId(phoneNumber);

    final payload = <String, dynamic>{
      'applicationId': config.applicationId,
      'password': config.password,
      'subscriberId': formattedPhone,
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json;charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return BdAppsSubscriptionStatusResponse.fromJson(data);
      } else {
        return BdAppsSubscriptionStatusResponse(
          statusCode: 'E${response.statusCode}',
          statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return BdAppsSubscriptionStatusResponse(
        statusCode: 'E500',
        statusDetail: 'Network request failed: $e',
      );
    }
  }

  /// Trigger user unsubscription.
  /// Uses `unsubscribe.php` when in Server Proxy Mode, or `/subscription/userSubscription` with action "0" when in Direct Mode.
  Future<BdAppsSubscriptionStatusResponse> unsubscribeUser({
    required String phoneNumber,
  }) async {
    final localPhone = formatLocalMobile(phoneNumber);

    if (isServerProxyMode) {
      final url = Uri.parse('$effectiveServerUrl/unsubscribe.php');
      try {
        final response = await _client.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'user_mobile': localPhone},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final subscriptionStatus = (data['subscriptionStatus'] ?? 'UNREGISTERED') as String;
          final statusCode = (data['statusCode'] ?? 'S1000') as String;
          final statusDetail = (data['statusDetail'] ?? '') as String;

          return BdAppsSubscriptionStatusResponse(
            statusCode: statusCode,
            statusDetail: statusDetail,
            subscriptionStatus: subscriptionStatus,
            version: (data['version'] as String?) ?? '1.0',
          );
        } else {
          return BdAppsSubscriptionStatusResponse(
            statusCode: 'E${response.statusCode}',
            statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        return BdAppsSubscriptionStatusResponse(
          statusCode: 'E500',
          statusDetail: 'Server error: $e',
        );
      }
    }

    // Direct BDApps TAP API Mode
    return _changeSubscription(phoneNumber: phoneNumber, action: '0');
  }

  /// Trigger direct user subscription (Direct TAP API Mode).
  Future<BdAppsSubscriptionStatusResponse> subscribeUser({
    required String phoneNumber,
  }) async {
    return _changeSubscription(phoneNumber: phoneNumber, action: '1');
  }

  Future<BdAppsSubscriptionStatusResponse> _changeSubscription({
    required String phoneNumber,
    required String action,
  }) async {
    final url = Uri.parse('$effectiveDirectBaseUrl/subscription/userSubscription');
    final formattedPhone = formatSubscriberId(phoneNumber);

    final payload = <String, dynamic>{
      'applicationId': config.applicationId,
      'password': config.password,
      'subscriberId': formattedPhone,
      'action': action,
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json;charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return BdAppsSubscriptionStatusResponse.fromJson(data);
      } else {
        return BdAppsSubscriptionStatusResponse(
          statusCode: 'E${response.statusCode}',
          statusDetail: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return BdAppsSubscriptionStatusResponse(
        statusCode: 'E500',
        statusDetail: 'Network request failed: $e',
      );
    }
  }
}
