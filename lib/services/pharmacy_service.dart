import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/pharmacy.dart';

class PharmacyService {
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error obtaining current position: $e');
      return null;
    }
  }

  Future<List<Pharmacy>> fetchNearbyPharmacies({
    required double latitude,
    required double longitude,
    double radiusMeters = 3000,
  }) async {
    try {
      // Overpass API query for pharmacies around the given lat/long
      final query =
          '[out:json][timeout:15];(node["amenity"="pharmacy"](around:$radiusMeters,$latitude,$longitude);way["amenity"="pharmacy"](around:$radiusMeters,$latitude,$longitude););out center;';
      final url = Uri.parse(
        'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = (data['elements'] as List?) ?? [];

        final pharmacies = <Pharmacy>[];
        for (final el in elements) {
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] as String? ?? tags['name:en'] as String? ?? 'Pharmacy';
          final street = tags['addr:street'] as String? ?? '';
          final city = tags['addr:city'] as String? ?? '';
          final address = [street, city].where((s) => s.isNotEmpty).join(', ');
          final phone = tags['phone'] as String? ?? tags['contact:phone'] as String?;

          final lat = (el['lat'] ?? el['center']?['lat'] as num?)?.toDouble() ?? latitude;
          final lon = (el['lon'] ?? el['center']?['lon'] as num?)?.toDouble() ?? longitude;

          final distance = Geolocator.distanceBetween(latitude, longitude, lat, lon);

          pharmacies.add(
            Pharmacy(
              id: el['id'].toString(),
              name: name,
              address: address.isNotEmpty ? address : 'Dhaka, Bangladesh',
              latitude: lat,
              longitude: lon,
              distanceMeters: distance,
              isOpen: tags['opening_hours'] != null ? true : null,
              phone: phone,
            ),
          );
        }

        pharmacies.sort(
          (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0),
        );
        return pharmacies;
      }
    } catch (e) {
      debugPrint('Failed to query Overpass API for pharmacies: $e');
    }

    // Default mock fallback nearby pharmacies for testing/offline support in Bangladesh
    return _generateFallbackPharmacies(latitude, longitude);
  }

  List<Pharmacy> _generateFallbackPharmacies(double lat, double lon) {
    return [
      Pharmacy(
        id: 'p1',
        name: 'Lazz Pharma (24 Hours)',
        address: 'Kalabagan Main Road, Dhaka',
        latitude: lat + 0.003,
        longitude: lon + 0.002,
        distanceMeters: 350,
        isOpen: true,
        rating: 4.6,
        phone: '01711223344',
      ),
      Pharmacy(
        id: 'p2',
        name: 'Tamanna Pharmacy',
        address: 'Mirpur Road, Dhanmondi, Dhaka',
        latitude: lat - 0.004,
        longitude: lon + 0.003,
        distanceMeters: 620,
        isOpen: true,
        rating: 4.4,
        phone: '01819887766',
      ),
      Pharmacy(
        id: 'p3',
        name: 'Health & Hope Pharmacy',
        address: 'Green Road, Panthapath, Dhaka',
        latitude: lat + 0.007,
        longitude: lon - 0.005,
        distanceMeters: 1100,
        isOpen: true,
        rating: 4.5,
        phone: '01911445566',
      ),
      Pharmacy(
        id: 'p4',
        name: 'Square Model Pharmacy',
        address: 'Panthapath, Dhaka',
        latitude: lat + 0.009,
        longitude: lon + 0.006,
        distanceMeters: 1450,
        isOpen: false,
        rating: 4.8,
        phone: '01700998877',
      ),
    ];
  }
}
