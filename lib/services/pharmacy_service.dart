import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service responsible for acquiring device GPS location and launching
/// Google Maps to locate nearby pharmacies.
class PharmacyService {
  /// Request and retrieve the user's current GPS position.
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

  /// Construct a universal Google Maps search URI with optional coordinates and search query.
  Uri buildGoogleMapsSearchUri({
    double? latitude,
    double? longitude,
    String query = 'pharmacy',
  }) {
    final String searchQuery;
    if (latitude != null && longitude != null) {
      searchQuery = '$query near $latitude,$longitude';
    } else {
      searchQuery = query;
    }

    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(searchQuery)}',
    );
  }

  /// Launch Google Maps app (or browser fallback) with the given search query and location.
  Future<bool> openNearbyPharmaciesInMaps({
    double? latitude,
    double? longitude,
    String query = 'pharmacy',
  }) async {
    // If coordinates were not provided, attempt to acquire them.
    if (latitude == null || longitude == null) {
      final position = await getCurrentPosition();
      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
      }
    }

    final uri = buildGoogleMapsSearchUri(
      latitude: latitude,
      longitude: longitude,
      query: query,
    );

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching Google Maps search: $e');
      return false;
    }
  }
}
