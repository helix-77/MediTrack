import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeoutOrUnavailable,
}

class LocationFetchResult {
  final Position? position;
  final LocationFailureReason? failureReason;

  const LocationFetchResult.success(this.position) : failureReason = null;
  const LocationFetchResult.failure(this.failureReason) : position = null;

  bool get isSuccess => position != null;
}

/// Service responsible for acquiring device GPS location and launching
/// Google Maps to locate nearby pharmacies.
class PharmacyService {
  /// Request and retrieve the user's current GPS position with robust fallbacks.
  Future<LocationFetchResult> getCurrentPositionDetailed() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationFetchResult.failure(LocationFailureReason.serviceDisabled);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationFetchResult.failure(LocationFailureReason.permissionDenied);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationFetchResult.failure(LocationFailureReason.permissionDeniedForever);
      }

      // 1. Try to get last known position first (fast, works on emulators & cached fixes)
      Position? lastKnown;
      try {
        lastKnown = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('Error getting last known position: $e');
      }

      // 2. Try to get a fresh fix
      try {
        final current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        return LocationFetchResult.success(current);
      } catch (e) {
        debugPrint('Error obtaining current fresh position: $e');
        if (lastKnown != null) {
          return LocationFetchResult.success(lastKnown);
        }
        return const LocationFetchResult.failure(LocationFailureReason.timeoutOrUnavailable);
      }
    } catch (e) {
      debugPrint('Unexpected error in getCurrentPositionDetailed: $e');
      return const LocationFetchResult.failure(LocationFailureReason.timeoutOrUnavailable);
    }
  }

  /// Request and retrieve the user's current GPS position (convenience wrapper).
  Future<Position?> getCurrentPosition() async {
    final result = await getCurrentPositionDetailed();
    return result.position;
  }

  /// Open device app settings.
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Open device location settings.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
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
