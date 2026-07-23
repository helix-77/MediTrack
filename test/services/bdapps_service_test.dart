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
    });

    test('formats BD phone number with +88 prefix', () {
      expect(BdAppsService.formatSubscriberId('+8801812345678'), 'tel:8801812345678');
    });

    test('formats BD phone number with 88 prefix', () {
      expect(BdAppsService.formatSubscriberId('8801812345678'), 'tel:8801812345678');
    });

    test('preserves tel: prefix if already present', () {
      expect(BdAppsService.formatSubscriberId('tel:8801812345678'), 'tel:8801812345678');
    });
  });

  group('BdAppsService API Tests', () {
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

    test('checkSubscriptionStatus queries subscriberStatus endpoint', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.bdapps.com/subscription/subscriberStatus');
        return http.Response(
          jsonEncode({
            'version': '1.0.',
            'statusCode': 'S1000',
            'statusDetail': 'Request was successfully processed',
            'subscriptionStatus': 'REGISTERED'
          }),
          200,
        );
      });

      final service = BdAppsService(config: testConfig, client: mockClient);
      final response = await service.checkSubscriptionStatus(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isTrue);
    });

    test('subscribeUser sends action 1 to userSubscription', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.bdapps.com/subscription/userSubscription');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], '1');

        return http.Response(
          jsonEncode({
            'version': '1.0.',
            'statusCode': 'S1000',
            'statusDetail': 'Success',
            'subscriptionStatus': 'REGISTERED'
          }),
          200,
        );
      });

      final service = BdAppsService(config: testConfig, client: mockClient);
      final response = await service.subscribeUser(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isTrue);
    });

    test('unsubscribeUser sends action 0 to userSubscription', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.bdapps.com/subscription/userSubscription');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], '0');

        return http.Response(
          jsonEncode({
            'version': '1.0.',
            'statusCode': 'S1000',
            'statusDetail': 'not registered',
            'subscriptionStatus': 'UNREGISTERED'
          }),
          200,
        );
      });

      final service = BdAppsService(config: testConfig, client: mockClient);
      final response = await service.unsubscribeUser(phoneNumber: '01812345678');

      expect(response.isSuccess, isTrue);
      expect(response.isRegistered, isFalse);
    });
  });
}
