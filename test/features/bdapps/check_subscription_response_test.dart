import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/features/bdapps/data/models/check_subscription_response.dart';

void main() {
  group('CheckSubscriptionResponse Model Tests', () {
    test('parses AppsPro status response with snake_case and raw', () {
      final json = {
        'subscription_status': 'REGISTERED',
        'status_code': 'S1000',
        'status_detail': 'Active subscriber',
        'raw': {
          'statusCode': 'S1000',
          'statusDetail': 'Success',
          'subscriptionStatus': 'REGISTERED',
        },
      };

      final response = CheckSubscriptionResponse.fromJson(json);
      expect(response.statusCode, 'S1000');
      expect(response.subscriptionStatus, 'REGISTERED');
      expect(response.isAlreadyActive, isTrue);
      expect(response.isSubscribed, isTrue);
      expect(response.isSuccess, isTrue);
    });

    test('parses AppsPro verify response with subscriber object', () {
      final json = {
        'valid': true,
        'subscriber': {
          'id': 'uuid-123',
          'bdapps_subscriber_id': 'tel:8801812345678',
          'phone_masked': '018****5678',
          'status': 'REGISTERED',
          'subscription_type': 'recurring',
          'frequency': 'daily',
        },
      };

      final response = CheckSubscriptionResponse.fromJson(json);
      expect(response.isAlreadyActive, isTrue);
      expect(response.isSubscribed, isTrue);
      expect(response.subscriberId, 'tel:8801812345678');
      expect(response.subscriptionStatus, 'REGISTERED');
    });

    test('parses unregistered / inactive status', () {
      final json = {
        'subscription_status': 'UNREGISTERED',
        'status_code': 'S1000',
        'status_detail': 'Not subscribed',
      };

      final response = CheckSubscriptionResponse.fromJson(json);
      expect(response.isAlreadyActive, isFalse);
      expect(response.isSubscribed, isFalse);
      expect(response.subscriptionStatus, 'UNREGISTERED');
    });
  });
}
