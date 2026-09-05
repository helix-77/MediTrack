import 'package:dio/dio.dart';

import 'models/check_subscription_response.dart';
import 'models/send_otp_response.dart';
import 'models/subscribe_response.dart';
import 'models/unsubscribe_response.dart';
import 'models/verify_otp_response.dart';

typedef FirebaseIdTokenProvider = Future<String?> Function();

/// Client for MediTrack's authenticated AppsPro Firebase proxy.
///
/// AppsPro SDK bearer endpoints require a secret key. That key is deliberately
/// held only by the appsProProxy Cloud Function; this client sends a Firebase
/// ID token and never calls AppsPro directly.
class AppsProApiClient {
  AppsProApiClient(this._dio, {FirebaseIdTokenProvider? idTokenProvider})
    : _idTokenProvider = idTokenProvider;

  final Dio _dio;
  final FirebaseIdTokenProvider? _idTokenProvider;

  Future<Map<String, dynamic>> _invoke(
    String action, {
    Map<String, dynamic>? data,
  }) async {
    final token = await _idTokenProvider?.call();
    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: <String, dynamic>{'action': action, ...?data},
      options: Options(
        headers: <String, dynamic>{
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Map<String, dynamic>? _errorBody(DioException error) {
    final data = error.response?.data;
    return data is Map<String, dynamic> ? data : null;
  }

  /// Checks AppsPro's live carrier status through the authenticated proxy.
  Future<CheckSubscriptionResponse> checkSubscription({
    required String userMobile,
  }) async {
    try {
      return CheckSubscriptionResponse.fromJson(
        await _invoke('status', data: {'phone': userMobile}),
      );
    } on DioException catch (e) {
      final body = _errorBody(e);
      return CheckSubscriptionResponse.fromJson(
        body ??
            <String, dynamic>{
              'subscription_status': 'UNKNOWN',
              'error': e.message ?? 'Network error checking subscription',
              'status_code': e.response?.statusCode?.toString() ?? 'E1000',
              'status_detail': e.message,
            },
      );
    } catch (e) {
      return CheckSubscriptionResponse(
        subscriptionStatus: 'UNKNOWN',
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Requests a carrier subscription OTP through the authenticated proxy.
  Future<SendOtpResponse> sendOtp({required String userMobile}) async {
    try {
      return SendOtpResponse.fromJson(
        await _invoke('otp_request', data: {'phone': userMobile}),
      );
    } on DioException catch (e) {
      final body = _errorBody(e);
      return SendOtpResponse.fromJson(
        body ??
            <String, dynamic>{
              'error': e.message ?? 'Connection error sending OTP',
              'status_code': e.response?.statusCode?.toString() ?? 'E1000',
              'status_detail': e.message,
            },
      );
    } catch (e) {
      return SendOtpResponse(
        isSuccess: false,
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Verifies a subscription OTP through the authenticated proxy.
  Future<VerifyOtpResponse> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    try {
      return VerifyOtpResponse.fromJson(
        await _invoke(
          'otp_verify',
          data: {'reference_no': referenceNo, 'otp': otp},
        ),
      );
    } on DioException catch (e) {
      final body = _errorBody(e);
      return VerifyOtpResponse.fromJson(
        body ??
            <String, dynamic>{
              'error': e.message ?? 'Verification connection failed',
              'status_code': e.response?.statusCode?.toString() ?? 'E1000',
              'status_detail': e.message,
            },
      );
    } catch (e) {
      return VerifyOtpResponse(
        isSuccess: false,
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Starts direct carrier subscription through the authenticated proxy.
  Future<SubscribeResponse> subscribe({required String userMobile}) async {
    try {
      return SubscribeResponse.fromJson(
        await _invoke('subscribe', data: {'phone': userMobile}),
      );
    } on DioException catch (e) {
      final body = _errorBody(e);
      return SubscribeResponse.fromJson(
        body ??
            <String, dynamic>{
              'success': false,
              'error': e.message,
              'status_code': e.response?.statusCode?.toString() ?? 'E1000',
              'status_detail': e.message ?? 'Server error',
            },
      );
    } catch (e) {
      return SubscribeResponse(
        success: false,
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Cancels only the authenticated user's linked carrier subscription.
  ///
  /// The function reads the linked phone from the authenticated user's profile.
  /// The legacy parameters remain for source compatibility and are not sent.
  Future<UnsubscribeResponse> unsubscribe({
    required String userMobile,
    String? subscriberId,
    String? referenceNo,
  }) async {
    try {
      return UnsubscribeResponse.fromJson(await _invoke('unsubscribe'));
    } on DioException catch (e) {
      final body = _errorBody(e);
      return UnsubscribeResponse.fromJson(
        body ??
            <String, dynamic>{
              'error': e.message ?? 'Network error unregistering',
              'status_code': e.response?.statusCode?.toString() ?? 'E1000',
              'status_detail': e.message ?? 'Network error unregistering',
            },
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

  /// Verifies a BDApps subscriber ID through the authenticated proxy.
  Future<CheckSubscriptionResponse> verifySubscriber({
    required String subscriberId,
  }) async {
    try {
      return CheckSubscriptionResponse.fromJson(
        await _invoke('verify', data: {'subscriber_id': subscriberId}),
      );
    } on DioException catch (e) {
      final body = _errorBody(e);
      return CheckSubscriptionResponse.fromJson(
        body ??
            <String, dynamic>{
              'subscription_status': 'UNKNOWN',
              'error': e.message ?? 'Network error verifying subscriber',
              'status_code': e.response?.statusCode?.toString() ?? 'E1000',
            },
      );
    } catch (e) {
      return CheckSubscriptionResponse(
        subscriptionStatus: 'UNKNOWN',
        error: e.toString(),
        statusCode: 'E1000',
      );
    }
  }

  /// Fetches public AppsPro metadata through the authenticated proxy.
  Future<Map<String, dynamic>?> getAppInfo({String? publishableKey}) async {
    try {
      return await _invoke(
        'app_info',
        data: {
          if (publishableKey != null && publishableKey.isNotEmpty)
            'publishable_key': publishableKey,
        },
      );
    } catch (_) {
      return null;
    }
  }
}
