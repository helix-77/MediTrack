import 'package:dio/dio.dart';

import 'models/send_sms_response.dart';

/// Calls the BD Apps SMS backend (`POST send_sms.php`) so the profile tab
/// can fire a test / notification SMS and surface the round-trip to the user.
///
/// Mirrors the wire format used by the rest of the BD Apps API:
/// form-encoded POST (`application/x-www-form-urlencoded`) — PHP's `$_POST`
/// reads from that. NOT JSON, NOT multipart `FormData` (Dio hard-overwrites
/// `FormData`'s content-type to `multipart/form-data`).
class SmsApiClient {
  SmsApiClient(this._dio);

  final Dio _dio;

  static final _formEncoded =
      Options(contentType: Headers.formUrlEncodedContentType);

  /// Sends a single SMS to [phoneNumber]. Returns the parsed response in
  /// both success and failure branches so callers can read `statusCode` /
  /// `statusDetail` / `error` regardless of branch.
  Future<SendSmsResponse> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/send_sms.php',
        data: {
          'user_mobile': phoneNumber,
          'message': message,
        },
        options: _formEncoded,
      );

      return SendSmsResponse.fromJson(response.data!);
    } on DioException catch (e) {
      return SendSmsResponse(
        success: false,
        statusCode: e.response?.statusCode?.toString() ?? 'E1000',
        statusDetail: e.message ?? 'Network error sending SMS',
        error: e.message,
      );
    } catch (e) {
      return SendSmsResponse(
        success: false,
        statusCode: 'E1000',
        statusDetail: e.toString(),
        error: e.toString(),
      );
    }
  }
}
