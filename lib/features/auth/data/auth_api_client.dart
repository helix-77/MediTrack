import 'package:dio/dio.dart';

import 'models/check_subscription_response.dart';
import 'models/send_otp_response.dart';
import 'models/unsubscribe_response.dart';
import 'models/verify_otp_response.dart';

/// Calls the real BD Apps OTP backend (send_otp.php / verify_otp.php /
/// unsubscribe.php / check_subscription.php). All endpoints read PHP
/// `$_POST`, so every request must be sent as
/// `application/x-www-form-urlencoded` — NOT JSON, NOT multipart `FormData`
/// (Dio hard-overwrites `FormData`'s content-type to `multipart/form-data`,
/// a different wire format).
class AuthApiClient {
  AuthApiClient(this._dio);

  final Dio _dio;

  static final _formEncoded =
      Options(contentType: Headers.formUrlEncodedContentType);

  Future<SendOtpResponse> sendOtp(String phoneNumber) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/send_otp.php',
      data: {'user_mobile': phoneNumber},
      options: _formEncoded,
    );

    // Always return the parsed body — including the `success: false`
    // branches — so callers can read `statusCode`/`statusDetail`/
    // `subscriberId` instead of getting only a thrown message string.
    return SendOtpResponse.fromJson(response.data!);
  }

  /// Sends the user-entered OTP + the `referenceNo` returned by the prior
  /// `sendOtp` call. The response carries no `success` flag — success is
  /// signaled by `statusCode == "S1000"`; see [VerifyOtpResponse.isSuccess].
  Future<VerifyOtpResponse> verifyOtp({
    required String referenceNo,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/verify_otp.php',
      data: {'Otp': code, 'referenceNo': referenceNo},
      options: _formEncoded,
    );

    // Always return the parsed body — including the failure branch — so
    // callers can read statusCode/statusDetail/subscriberId instead of
    // getting only a thrown message string.
    return VerifyOtpResponse.fromJson(response.data!);
  }

  /// Returns the current subscription status for a subscriber.
  Future<CheckSubscriptionResponse> checkSubscription({
    required String userMobile,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/check_subscription.php',
      data: {'user_mobile': userMobile},
      options: _formEncoded,
    );

    return CheckSubscriptionResponse.fromJson(response.data!);
  }

  /// Tells the backend to unregister the given mobile number. Success is
  /// signaled by `statusCode == "S1000"`; see [UnsubscribeResponse.isSuccess].
  Future<UnsubscribeResponse> unsubscribe({required String userMobile}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/unsubscribe.php',
      data: {'user_mobile': userMobile},
      options: _formEncoded,
    );

    return UnsubscribeResponse.fromJson(response.data!);
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;

  @override
  String toString() => message;
}