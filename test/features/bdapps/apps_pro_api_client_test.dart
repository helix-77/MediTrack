import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/features/bdapps/data/apps_pro_api_client.dart';

void main() {
  group('AppsProApiClient Tests', () {
    late Dio dio;
    late AppsProApiClient client;
    Map<String, dynamic>? mockResponseBody;
    int mockStatusCode = 200;
    RequestOptions? lastRequest;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.appspro.dev/api/v1'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        handler: (options) {
          lastRequest = options;
          final data = jsonEncode(mockResponseBody ?? {});
          return ResponseBody(
            Stream.value(Uint8List.fromList(utf8.encode(data))),
            mockStatusCode,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        },
      );
      client = AppsProApiClient(
        dio,
        idTokenProvider: () async => 'firebase-token',
      );
    });

    test(
      'checkSubscription calls the proxy with a Firebase token and parses response',
      () async {
        mockResponseBody = {
          'subscription_status': 'REGISTERED',
          'status_code': 'S1000',
          'status_detail': 'Subscriber is active',
          'raw': {'statusCode': 'S1000', 'subscriptionStatus': 'REGISTERED'},
        };
        mockStatusCode = 200;

        final res = await client.checkSubscription(userMobile: '01812345678');
        expect(res.isAlreadyActive, isTrue);
        expect(res.isSubscribed, isTrue);
        expect(res.statusCode, 'S1000');
        expect(lastRequest?.data, {'action': 'status', 'phone': '01812345678'});
        expect(lastRequest?.headers['Authorization'], 'Bearer firebase-token');
      },
    );

    test('sendOtp calls /sdk/otp/request and parses reference_no', () async {
      mockResponseBody = {
        'reference_no': 'REF998877',
        'status_code': 'S1000',
        'status_detail': 'OTP sent',
      };
      mockStatusCode = 200;

      final res = await client.sendOtp(userMobile: '01812345678');
      expect(res.isSuccess, isTrue);
      expect(res.referenceNo, 'REF998877');
    });

    test('verifyOtp calls /sdk/otp/verify and parses result', () async {
      mockResponseBody = {
        'subscription_status': 'REGISTERED',
        'subscriber_id': 'tel:8801812345678',
        'local_subscriber_id': 'loc-1',
        'status_code': 'S1000',
      };
      mockStatusCode = 200;

      final res = await client.verifyOtp(
        referenceNo: 'REF998877',
        otp: '123456',
      );
      expect(res.isSuccess, isTrue);
      expect(res.isSubscribed, isTrue);
      expect(res.subscriberId, 'tel:8801812345678');
    });

    test('subscribe calls /sdk/subscribe and parses result', () async {
      mockResponseBody = {
        'status_code': 'S1000',
        'status_detail': 'Subscribed',
        'subscription_status': 'REGISTERED',
      };
      mockStatusCode = 200;

      final res = await client.subscribe(userMobile: '01812345678');
      expect(res.isSuccess, isTrue);
      expect(res.statusCode, 'S1000');
    });

    test(
      'unsubscribe never sends the phone to the proxy and parses result',
      () async {
        mockResponseBody = {
          'status_code': 'S1000',
          'status_detail': 'Unsubscribed',
          'subscription_status': 'UNREGISTERED',
        };
        mockStatusCode = 200;

        final res = await client.unsubscribe(userMobile: '01812345678');
        expect(res.isSuccess, isTrue);
        expect(res.isUnregistered, isTrue);
        expect(lastRequest?.data, {'action': 'unsubscribe'});
      },
    );

    test('verifySubscriber calls /sdk/verify/{id} and parses valid', () async {
      mockResponseBody = {
        'valid': true,
        'subscriber': {
          'id': 'sub-uuid',
          'bdapps_subscriber_id': 'tel:8801812345678',
          'status': 'REGISTERED',
        },
      };
      mockStatusCode = 200;

      final res = await client.verifySubscriber(
        subscriberId: 'tel:8801812345678',
      );
      expect(res.isAlreadyActive, isTrue);
      expect(res.subscriberId, 'tel:8801812345678');
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter({required this.handler});

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
