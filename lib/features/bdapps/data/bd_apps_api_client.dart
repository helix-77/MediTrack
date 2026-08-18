import 'package:dio/dio.dart';

import 'models/check_subscription_response.dart';
import 'models/send_otp_response.dart';
import 'models/subscribe_response.dart';
import 'models/unsubscribe_response.dart';
import 'models/verify_otp_response.dart';

/// Calls the BD Apps subscription backend (`subscribe.php`, `send_otp.php`,
/// `verify_otp.php`, `check_subscription.php`, `unsubscribe.php`).
///
/// All endpoints read PHP `$_POST`, so every request is sent as
/// `application/x-www-form-urlencoded`.
class BdAppsApiClient {
  BdAppsApiClient(this._dio);

  final Dio _dio;

  static final _formEncoded =
      Options(contentType: Headers.formUrlEncodedContentType);

  /// Initiates the direct carrier subscription flow for Robi/Airtel subscribers.
  Future<SubscribeResponse> subscribe({
    required String userMobile,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/subscribe.php',
        data: {'user_mobile': userMobile},
        options: _formEncoded,
      );

      return SubscribeResponse.fromJson(response.data!);
    } on DioException catch (e) {
      return SubscribeResponse(
        success: false,
        error: e.response?.data is Map ? e.response?.data['error']?.toString() : e.message,
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
        statusDetail: e.message ?? 'Server error',
      );
    } catch (e) {
      return SubscribeResponse(
        success: false,
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Requests a subscription OTP from BD Apps for the given mobile number.
  Future<SendOtpResponse> sendOtp({
    required String userMobile,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/send_otp.php',
        data: {'user_mobile': userMobile},
        options: _formEncoded,
      );

      return SendOtpResponse.fromJson(response.data!);
    } on DioException catch (e) {
      return SendOtpResponse(
        isSuccess: false,
        error: e.message ?? 'Connection error',
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
        statusDetail: e.message,
      );
    } catch (e) {
      return SendOtpResponse(
        isSuccess: false,
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Verifies the OTP code entered by the user against BD Apps referenceNo.
  Future<VerifyOtpResponse> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/verify_otp.php',
        data: {
          'referenceNo': referenceNo,
          'otp': otp,
        },
        options: _formEncoded,
      );

      return VerifyOtpResponse.fromJson(response.data!);
    } on DioException catch (e) {
      return VerifyOtpResponse(
        isSuccess: false,
        error: e.message ?? 'Verification connection failed',
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
        statusDetail: e.message,
      );
    } catch (e) {
      return VerifyOtpResponse(
        isSuccess: false,
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Returns the current subscription status for a subscriber.
  Future<CheckSubscriptionResponse> checkSubscription({
    required String userMobile,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/check_subscription.php',
        data: {'user_mobile': userMobile},
        options: _formEncoded,
      );

      return CheckSubscriptionResponse.fromJson(response.data!);
    } on DioException catch (e) {
      return CheckSubscriptionResponse(
        subscriptionStatus: 'UNKNOWN',
        error: e.message ?? 'Network error checking subscription',
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
        statusDetail: e.message,
      );
    } catch (e) {
      return CheckSubscriptionResponse(
        subscriptionStatus: 'UNKNOWN',
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Tells the backend to unregister the given mobile number.
  Future<UnsubscribeResponse> unsubscribe({required String userMobile}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/unsubscribe.php',
        data: {'user_mobile': userMobile},
        options: _formEncoded,
      );

      return UnsubscribeResponse.fromJson(response.data!);
    } on DioException catch (e) {
      return UnsubscribeResponse(
        success: false,
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
        statusDetail: e.message ?? 'Network error unregistering',
        error: e.message ?? 'Network error unregistering',
      );
    } catch (e) {
      return UnsubscribeResponse(
        success: false,
        statusCode: 'E1000',
        statusDetail: e.toString(),
        error: e.toString(),
      );
    }
  }
}
