import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/features/bdapps/data/models/verify_otp_response.dart';

void main() {
  group('VerifyOtpResponse Model Tests', () {
    test('parses AppsPro verify OTP success response', () {
      final json = {
        'subscription_status': 'REGISTERED',
        'subscriber_id': 'tel:8801812345678',
        'local_subscriber_id': 'loc-sub-99',
        'status_code': 'S1000',
        'status_detail': 'OTP verified successfully',
        'raw': {
          'statusCode': 'S1000',
          'statusDetail': 'Success',
        },
      };

      final response = VerifyOtpResponse.fromJson(json);
      expect(response.isSuccess, isTrue);
      expect(response.isSubscribed, isTrue);
      expect(response.subscriptionStatus, 'REGISTERED');
      expect(response.subscriberId, 'tel:8801812345678');
      expect(response.localSubscriberId, 'loc-sub-99');
      expect(response.statusCode, 'S1000');
    });

    test('parses AppsPro verify OTP failure response', () {
      final json = {
        'status_code': 'E1000',
        'status_detail': 'Invalid OTP',
      };

      final response = VerifyOtpResponse.fromJson(json);
      expect(response.isSuccess, isFalse);
      expect(response.isSubscribed, isFalse);
    });
  });
}
