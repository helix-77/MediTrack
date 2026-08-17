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
  final bool isEmulatorDefault;

  const LocationFetchResult.success(this.position, {this.isEmulatorDefault = false})
      : failureReason = null;
  const LocationFetchResult.failure(this.failureReason)
      : position = null,
        isEmulatorDefault = false;

  bool get isSuccess => position != null;
}

/// Service responsible for acquiring device GPS location and launching
/// Google Maps to locate nearby pharmacies.
class PharmacyService {
  /// Check if coordinates match the Android Emulator default (Mountain View, CA).
  static bool isDefaultEmulatorLocation(double lat, double lon) {
    return (lat >= 37.41 && lat <= 37.43) && (lon >= -122.09 && lon <= -122.07);
  }

  /// Request and retrieve the user's current GPS position with high accuracy.
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

      // 1. Attempt to obtain a fresh high-accuracy position from GPS / Fused Provider
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (e) {
        debugPrint('Fresh position acquisition timed out or failed: $e');
      }

      // 2. Fall back to last known position if fresh position timed out
      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (e) {
          debugPrint('Error getting last known position: $e');
        }
      }

      if (position != null) {
        final isEmulator = isDefaultEmulatorLocation(position.latitude, position.longitude);
        return LocationFetchResult.success(position, isEmulatorDefault: isEmulator);
      }

      return const LocationFetchResult.failure(LocationFailureReason.timeoutOrUnavailable);
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

  /// Construct a native geo: URI for Android maps intent.
  Uri buildGeoSearchUri({
    double? latitude,
    double? longitude,
    String query = 'pharmacy',
  }) {
    final lat = latitude ?? 0;
    final lon = longitude ?? 0;
    return Uri.parse('geo:$lat,$lon?q=${Uri.encodeComponent(query)}');
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

    // 1. Try launching with native geo: URI on Android/iOS
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final geoUri = buildGeoSearchUri(
          latitude: latitude,
          longitude: longitude,
          query: query,
        );
        if (await canLaunchUrl(geoUri)) {
          final launched = await launchUrl(
            geoUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('Failed to launch geo URI, falling back to HTTPS: $e');
      }
    }

    // 2. Fallback to HTTPS Google Maps Search URL
    final httpsUri = buildGoogleMapsSearchUri(
      latitude: latitude,
      longitude: longitude,
      query: query,
    );

    try {
      return await launchUrl(
        httpsUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching Google Maps HTTPS search: $e');
      return false;
    }
  }
}
