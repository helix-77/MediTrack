import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/features/bdapps/data/models/unsubscribe_response.dart';

void main() {
  group('UnsubscribeResponse Model Tests', () {
    test('parses successful unsubscribe response', () {
      final json = {
        'success': true,
        'subscriberId': 'tel:8801812345678',
        'statusCode': 'S1000',
        'statusDetail': 'Unsubscribed successfully.',
        'subscriptionStatus': 'UNREGISTERED',
        'version': '1.0',
        'action': '1',
      };

      final response = UnsubscribeResponse.fromJson(json);
      expect(response.statusCode, 'S1000');
      expect(response.subscriptionStatus, 'UNREGISTERED');
      expect(response.isSuccess, isTrue);
      expect(response.isUnregistered, isTrue);
      expect(response.subscriberId, 'tel:8801812345678');
      expect(response.error, isNull);
    });

    test('parses failed unsubscribe response with error code', () {
      final json = {
        'success': false,
        'subscriberId': 'tel:8801812345678',
        'statusCode': 'E1351',
        'statusDetail': 'User is not subscribed.',
        'subscriptionStatus': 'UNKNOWN',
        'error': 'User is not subscribed.',
      };

      final response = UnsubscribeResponse.fromJson(json);
      expect(response.statusCode, 'E1351');
      expect(response.isSuccess, isFalse);
      expect(response.isUnregistered, isFalse);
      expect(response.error, 'User is not subscribed.');
      expect(response.statusDetail, 'User is not subscribed.');
    });

    test('handles boolean variants in success field', () {
      final res1 = UnsubscribeResponse.fromJson({'success': 1, 'statusCode': 'S1000'});
      expect(res1.isSuccess, isTrue);

      final res2 = UnsubscribeResponse.fromJson({'success': 'true', 'statusCode': 'S1000'});
      expect(res2.isSuccess, isTrue);

      final res3 = UnsubscribeResponse.fromJson({'success': 0, 'statusCode': 'E1000'});
      expect(res3.isSuccess, isFalse);
    });

    test('parses BDApps E1951 carrier address rejection as failure', () {
      final json = {
        'status_code': 'E1951',
        'status_detail':
            'Format of the address is invalid Or User Already UnRegistered',
        'raw': {
          'statusCode': 'E1951',
          'statusDetail':
              'Format of the address is invalid Or User Already UnRegistered',
        },
      };

      final response = UnsubscribeResponse.fromJson(json);
      expect(response.statusCode, 'E1951');
      expect(response.isCarrierAddressRejected, isTrue);
      expect(response.isSuccess, isFalse);
      expect(response.isUnregistered, isFalse);
      expect(response.error, contains('E1951'));
    });

    test('handles string-encoded raw json payload for E1951 as failure', () {
      final json = {
        'raw':
            '{"statusCode":"E1951","statusDetail":"Format of the address is invalid Or User Already UnRegistered"}',
      };

      final response = UnsubscribeResponse.fromJson(json);
      expect(response.statusCode, 'E1951');
      expect(response.isCarrierAddressRejected, isTrue);
      expect(response.isSuccess, isFalse);
      expect(response.isUnregistered, isFalse);
    });
  });
}
