import 'package:dio/dio.dart';

import 'models/check_subscription_response.dart';
import 'models/send_otp_response.dart';
import 'models/subscribe_response.dart';
import 'models/unsubscribe_response.dart';
import 'models/verify_otp_response.dart';

/// Client for calling AppsPro API v1 SDK endpoints:
/// - `POST /sdk/status`
/// - `POST /sdk/otp/request`
/// - `POST /sdk/otp/verify`
/// - `POST /sdk/subscribe`
/// - `POST /sdk/unsubscribe`
/// - `GET /sdk/verify/{subscriber_id}`
/// - `GET /sdk/app-info`
///
/// Authenticated calls send `Authorization: Bearer <APPS_PRO_SECRET_KEY>`.
class AppsProApiClient {
  AppsProApiClient(this._dio);

  final Dio _dio;

  /// Checks subscription status directly via AppsPro live query.
  Future<CheckSubscriptionResponse> checkSubscription({
    required String userMobile,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sdk/status',
        data: {'phone': userMobile},
      );

      return CheckSubscriptionResponse.fromJson(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        return CheckSubscriptionResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
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

  /// Sends a subscription OTP request to the subscriber's phone number.
  Future<SendOtpResponse> sendOtp({
    required String userMobile,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sdk/otp/request',
        data: {'phone': userMobile},
      );

      return SendOtpResponse.fromJson(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        return SendOtpResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
      return SendOtpResponse(
        isSuccess: false,
        error: e.message ?? 'Connection error sending OTP',
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

  /// Verifies the OTP code entered by the user with the reference number.
  Future<VerifyOtpResponse> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sdk/otp/verify',
        data: {
          'reference_no': referenceNo,
          'otp': otp,
        },
      );

      return VerifyOtpResponse.fromJson(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        return VerifyOtpResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
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

  /// Directly initiates the carrier subscription without OTP (if supported).
  Future<SubscribeResponse> subscribe({
    required String userMobile,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sdk/subscribe',
        data: {'phone': userMobile},
      );

      return SubscribeResponse.fromJson(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        return SubscribeResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
      return SubscribeResponse(
        success: false,
        error: e.message,
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

  /// Cancels / unsubscribes the subscriber from the app's service.
  Future<UnsubscribeResponse> unsubscribe({
    required String userMobile,
    String? subscriberId,
    String? referenceNo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sdk/unsubscribe',
        data: {'phone': userMobile},
      );

      return UnsubscribeResponse.fromJson(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        return UnsubscribeResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
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

  /// Verifies a BDApps subscriber ID against AppsPro.
  Future<CheckSubscriptionResponse> verifySubscriber({
    required String subscriberId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sdk/verify/$subscriberId',
      );

      return CheckSubscriptionResponse.fromJson(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.data is Map<String, dynamic>) {
        return CheckSubscriptionResponse.fromJson(
          e.response!.data as Map<String, dynamic>,
        );
      }
      return CheckSubscriptionResponse(
        subscriptionStatus: 'UNKNOWN',
        error: e.message ?? 'Network error verifying subscriber',
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
      );
    } catch (e) {
      return CheckSubscriptionResponse(
        subscriptionStatus: 'UNKNOWN',
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Fetches public app info from AppsPro.
  Future<Map<String, dynamic>?> getAppInfo({String? publishableKey}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/sdk/app-info',
        queryParameters: {
          if (publishableKey != null && publishableKey.isNotEmpty)
            'publishable_key': publishableKey,
        },
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }
}
