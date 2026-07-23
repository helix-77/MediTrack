import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bdapps_models.dart';

/// Service responsible for communicating with BDApps TAP APIs.
/// Supports OTP generation, OTP verification, direct subscription/unsubscription,
/// and subscriber status checks.
class BdAppsService {
  final BdAppsConfig config;
  final http.Client _client;

  BdAppsService({
    BdAppsConfig? config,
    http.Client? client,
  })  : config = config ??
            const BdAppsConfig(
              applicationId: 'APP_000000',
              password: 'password',
            ),
        _client = client ?? http.Client();

  /// Formats raw phone number input into BDApps `tel:8801XXXXXXXXX` format.
  static String formatSubscriberId(String rawPhone) {
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

    return 'tel:88$clean';
  }

  /// Request OTP for a subscriber's phone number.
  /// Endpoint: `/otp/request`
  Future<BdAppsOtpResponse> requestOtp({
    required String phoneNumber,
    String applicationHash = 'bdapps',
    Map<String, String>? applicationMetaData,
  }) async {
    final url = Uri.parse('${config.baseUrl}/otp/request');
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
  /// Endpoint: `/otp/verify`
  Future<BdAppsOtpVerifyResponse> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    final url = Uri.parse('${config.baseUrl}/otp/verify');

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
  /// Endpoint: `/subscription/subscriberStatus`
  Future<BdAppsSubscriptionStatusResponse> checkSubscriptionStatus({
    required String phoneNumber,
  }) async {
    final url = Uri.parse('${config.baseUrl}/subscription/subscriberStatus');
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

  /// Trigger direct user subscription.
  /// Endpoint: `/subscription/userSubscription` with action "1"
  Future<BdAppsSubscriptionStatusResponse> subscribeUser({
    required String phoneNumber,
  }) async {
    return _changeSubscription(phoneNumber: phoneNumber, action: '1');
  }

  /// Trigger user unsubscription.
  /// Endpoint: `/subscription/userSubscription` with action "0"
  Future<BdAppsSubscriptionStatusResponse> unsubscribeUser({
    required String phoneNumber,
  }) async {
    return _changeSubscription(phoneNumber: phoneNumber, action: '0');
  }

  Future<BdAppsSubscriptionStatusResponse> _changeSubscription({
    required String phoneNumber,
    required String action,
  }) async {
    final url = Uri.parse('${config.baseUrl}/subscription/userSubscription');
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
