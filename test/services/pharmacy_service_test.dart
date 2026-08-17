import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/services/pharmacy_service.dart';

void main() {
  group('PharmacyService Tests', () {
    late PharmacyService service;

    setUp(() {
      service = PharmacyService();
    });

    test('builds Google Maps search URI with coordinates and default query', () {
      final uri = service.buildGoogleMapsSearchUri(
        latitude: 23.8103,
        longitude: 90.4125,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'pharmacy near 23.8103,90.4125');
    });

    test('builds Google Maps search URI with custom query and coordinates', () {
      final uri = service.buildGoogleMapsSearchUri(
        latitude: 23.8103,
        longitude: 90.4125,
        query: '24 hours pharmacy',
      );

      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '24 hours pharmacy near 23.8103,90.4125');
    });

    test('builds Google Maps search URI without coordinates as fallback', () {
      final uri = service.buildGoogleMapsSearchUri(
        query: 'pharmacy',
      );

      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'pharmacy');
    });

    test('builds geo search URI correctly', () {
      final uri = service.buildGeoSearchUri(
        latitude: 23.8103,
        longitude: 90.4125,
        query: 'pharmacy',
      );

      expect(uri.scheme, 'geo');
      expect(uri.path, '23.8103,90.4125');
      expect(uri.queryParameters['q'], 'pharmacy');
    });

    test('identifies Android emulator default location', () {
      expect(PharmacyService.isDefaultEmulatorLocation(37.421998, -122.084000), isTrue);
      expect(PharmacyService.isDefaultEmulatorLocation(23.8103, 90.4125), isFalse);
    });
  });
}
