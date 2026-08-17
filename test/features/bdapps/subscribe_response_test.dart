import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/features/bdapps/data/models/subscribe_response.dart';

void main() {
  group('SubscribeResponse Model Tests', () {
    test('parses successful registered response', () {
      final json = {
        'statusCode': 'S1000',
        'statusDetail': 'Process completed successfully.',
        'subscriptionStatus': 'REGISTERED',
        'version': '1.0',
        'raw': {
          'statusCode': 'S1000',
          'statusDetail': 'Success',
        },
      };

      final response = SubscribeResponse.fromJson(json);
      expect(response.statusCode, 'S1000');
      expect(response.subscriptionStatus, 'REGISTERED');
      expect(response.isRegistered, isTrue);
      expect(response.isSubscribed, isTrue);
      expect(response.isRequestAccepted, isTrue);
      expect(response.isPending, isFalse);
    });

    test('parses pending subscription response', () {
      final json = {
        'statusCode': 'S1000',
        'statusDetail': 'Request accepted for processing.',
        'subscriptionStatus': 'PENDING_CHARGING',
      };

      final response = SubscribeResponse.fromJson(json);
      expect(response.isRegistered, isFalse);
      expect(response.isPending, isTrue);
      expect(response.isRequestAccepted, isTrue);
    });

    test('parses failed subscription response', () {
      final json = {
        'statusCode': 'E1351',
        'statusDetail': 'User is not allowed to register or insufficient balance.',
      };

      final response = SubscribeResponse.fromJson(json);
      expect(response.isRegistered, isFalse);
      expect(response.isPending, isFalse);
      expect(response.isRequestAccepted, isFalse);
    });
  });
}
