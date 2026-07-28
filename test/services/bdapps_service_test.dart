import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditrack/models/bdapps_models.dart';
import 'package:meditrack/services/bdapps_service.dart';

void main() {
  group('BdAppsService Phone Formatting Tests', () {
    test('formats local BD phone number starting with 01', () {
      expect(BdAppsService.formatSubscriberId('01812345678'), 'tel:8801812345678');
      expect(BdAppsService.formatLocalMobile('01812345678'), '01812345678');
    });

    test('formats BD phone number with +88 prefix', () {
      expect(BdAppsService.formatSubscriberId('+8801812345678'), 'tel:8801812345678');
      expect(BdAppsService.formatLocalMobile('+8801812345678'), '01812345678');
    });

    test('formats BD phone number with 88 prefix', () {
      expect(BdAppsService.formatSubscriberId('8801812345678'), 'tel:8801812345678');
      expect(BdAppsService.formatLocalMobile('8801812345678'), '01812345678');
    });

    test('preserves tel: prefix if already present', () {
      expect(BdAppsService.formatSubscriberId('tel:8801812345678'), 'tel:8801812345678');
      expect(BdAppsService.formatLocalMobile('tel:8801812345678'), '01812345678');
    });
  });

  group('BdAppsService PHP Proxy Server Mode Tests', () {
    const serverUrl = 'https://my-server.com/api';

    test('requestOtp posts user_mobile to send_otp.php using formUrlEncoded', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://my-server.com/api/send_otp.php');
        expect(request.headers['Content-Type'], contains('application/x-www-form-urlencoded'));
        expect(request.bodyFields['user_mobile'], '01812345678');

        return http.Response(
          jsonEncode({
            'success': true,
            'referenceNo': 'REF_SERVER_999',
            'statusCode': 'S1000',
            'statusDetail': 'OTP requested successfully'
          }),
          200,
        );
      });

      final service = BdAppsService(serverUrl: serverUrl, client: mockClient);
      final response = await service.requestOtp(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.referenceNo, 'REF_SERVER_999');
    });

    test('verifyOtp posts referenceNo and Otp to verify_otp.php using formUrlEncoded', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://my-server.com/api/verify_otp.php');
        expect(request.headers['Content-Type'], contains('application/x-www-form-urlencoded'));
        expect(request.bodyFields['referenceNo'], 'REF_SERVER_999');
        expect(request.bodyFields['Otp'], '654321');

        return http.Response(
          jsonEncode({
            'statusCode': 'S1000',
            'subscriptionStatus': 'REGISTERED',
            'statusDetail': 'Success',
            'subscriberId': 'tel:8801812345678'
          }),
          200,
        );
      });

      final service = BdAppsService(serverUrl: serverUrl, client: mockClient);
      final response = await service.verifyOtp(referenceNo: 'REF_SERVER_999', otp: '654321');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isTrue);
    });

    test('checkSubscriptionStatus posts user_mobile to check_subscription.php', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://my-server.com/api/check_subscription.php');
        expect(request.bodyFields['user_mobile'], '01812345678');

        return http.Response(
          jsonEncode({
            'subscriptionStatus': 'REGISTERED',
            'isSubscribed': true,
            'statusCode': 'S1000'
          }),
          200,
        );
      });

      final service = BdAppsService(serverUrl: serverUrl, client: mockClient);
      final response = await service.checkSubscriptionStatus(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isTrue);
    });

    test('unsubscribeUser posts user_mobile to unsubscribe.php', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://my-server.com/api/unsubscribe.php');
        expect(request.bodyFields['user_mobile'], '01812345678');

        return http.Response(
          jsonEncode({
            'success': true,
            'subscriptionStatus': 'UNREGISTERED',
            'statusCode': 'S1000'
          }),
          200,
        );
      });

      final service = BdAppsService(serverUrl: serverUrl, client: mockClient);
      final response = await service.unsubscribeUser(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isFalse);
    });
  });

  group('BdAppsService Direct TAP API Mode Tests', () {
    const testConfig = BdAppsConfig(
      applicationId: 'APP_TEST',
      password: 'test_password',
      baseUrl: 'https://api.bdapps.com',
    );

    test('requestOtp sends correct payload and handles success response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.bdapps.com/otp/request');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['applicationId'], 'APP_TEST');
        expect(body['subscriberId'], 'tel:8801812345678');

        return http.Response(
          jsonEncode({
            'version': '1.0',
            'statusCode': 'S1000',
            'referenceNo': 'REF_123456',
            'statusDetail': 'Success'
          }),
          200,
        );
      });

      final service = BdAppsService(config: testConfig, client: mockClient);
      final response = await service.requestOtp(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.referenceNo, 'REF_123456');
    });

    test('verifyOtp sends correct payload and parses REGISTERED status', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.bdapps.com/otp/verify');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['referenceNo'], 'REF_123456');
        expect(body['otp'], '123456');

        return http.Response(
          jsonEncode({
            'version': '1.0',
            'statusCode': 'S1000',
            'subscriptionStatus': 'REGISTERED',
            'statusDetail': 'Success',
            'subscriberId': 'tel:8801812345678'
          }),
          200,
        );
      });

      final service = BdAppsService(config: testConfig, client: mockClient);
      final response = await service.verifyOtp(referenceNo: 'REF_123456', otp: '123456');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isTrue);
      expect(response.subscriberId, 'tel:8801812345678');
    });
  });
}
