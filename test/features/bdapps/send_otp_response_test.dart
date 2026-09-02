import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/features/bdapps/data/models/send_otp_response.dart';

void main() {
  group('SendOtpResponse Model Tests', () {
    test('parses AppsPro OTP request response with reference_no', () {
      final json = {
        'reference_no': 'REF12345678',
        'status_code': 'S1000',
        'status_detail': 'OTP sent successfully',
        'raw': {
          'statusCode': 'S1000',
          'statusDetail': 'Success',
        },
      };

      final response = SendOtpResponse.fromJson(json);
      expect(response.referenceNo, 'REF12345678');
      expect(response.statusCode, 'S1000');
      expect(response.isSuccess, isTrue);
      expect(response.isAlreadyRegistered, isFalse);
    });

    test('detects already registered subscriber on OTP request', () {
      final json = {
        'status_code': 'E1351',
        'status_detail': 'User already registered',
      };

      final response = SendOtpResponse.fromJson(json);
      expect(response.isAlreadyRegistered, isTrue);
    });
  });
}
