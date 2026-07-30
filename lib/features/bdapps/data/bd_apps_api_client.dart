import 'package:dio/dio.dart';

import 'models/check_subscription_response.dart';
import 'models/unsubscribe_response.dart';

/// Calls the BD Apps subscription backend (`check_subscription.php` /
/// `unsubscribe.php`). The OTP login flow has been removed, so this client
/// is intentionally narrower than the original `AuthApiClient` — it only
/// covers the actions the Profile tab exposes.
///
/// All endpoints read PHP `$_POST`, so every request is sent as
/// `application/x-www-form-urlencoded` — NOT JSON, NOT multipart `FormData`
/// (Dio hard-overwrites `FormData`'s content-type to `multipart/form-data`,
/// a different wire format).
class BdAppsApiClient {
  BdAppsApiClient(this._dio);

  final Dio _dio;

  static final _formEncoded =
      Options(contentType: Headers.formUrlEncodedContentType);

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
