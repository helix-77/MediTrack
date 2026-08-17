import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../logic/entitlement_guard.dart';
import '../services/entitlement_service.dart';
import '../services/pharmacy_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class NearbyPharmaciesScreen extends StatefulWidget {
  const NearbyPharmaciesScreen({super.key});

  @override
  State<NearbyPharmaciesScreen> createState() => _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState extends State<NearbyPharmaciesScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isOpeningMap = false;
  LocationFailureReason? _failureReason;
  bool _isEntitled = true;

  final List<_PharmacyCategory> _categories = const [
    _PharmacyCategory(
      title: 'All Nearby Pharmacies',
      subtitle: 'Drugstores, dispensaries, and retail medicine shops',
      query: 'pharmacy',
      icon: Icons.local_pharmacy_rounded,
      color: AppColors.primaryGreen,
    ),
    _PharmacyCategory(
      title: '24-Hour Pharmacies',
      subtitle: 'Open 24/7 for urgent and late-night medications',
      query: '24 hours pharmacy',
      icon: Icons.access_time_filled_rounded,
      color: Color(0xFF2E7D32),
    ),
    _PharmacyCategory(
      title: 'Hospital & Model Pharmacies',
      subtitle: 'DGDA accredited model pharmacies and hospital stores',
      query: 'model pharmacy',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF1565C0),
    ),
    _PharmacyCategory(
      title: 'Medicine & Surgical Stores',
      subtitle: 'Surgical supplies, diagnostic items, and medicines',
      query: 'medicine store',
      icon: Icons.medical_services_rounded,
      color: Color(0xFF7B1FA2),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkEntitlementAndDetectLocation();
    });
  }

  Future<void> _checkEntitlementAndDetectLocation() async {
    final entitlement = context.read<EntitlementService>();
    final isAllowed = await entitlement.requirePremium(
      context,
      feature: EntitlementFeature.nearbyPharmacy,
    );

    if (!isAllowed || !mounted) {
      setState(() {
        _isEntitled = false;
        _isLoadingLocation = false;
      });
      return;
    }

    setState(() {
      _isEntitled = true;
    });

    await _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _failureReason = null;
    });

    final result = await _pharmacyService.getCurrentPositionDetailed();

    if (!mounted) return;

    setState(() {
      _isLoadingLocation = false;
      _currentPosition = result.position;
      _failureReason = result.failureReason;
    });
  }

  void _useDhakaCoordinates() {
    setState(() {
      _currentPosition = Position(
        latitude: 23.8103,
        longitude: 90.4125,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _failureReason = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location set to Dhaka Center (23.8103° N, 90.4125° E)'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchMapsSearch({String query = 'pharmacy'}) async {
    if (_isOpeningMap) return;

    setState(() {
      _isOpeningMap = true;
    });

    try {
      final success = await _pharmacyService.openNearbyPharmaciesInMaps(
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        query: query,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Maps. Please verify your browser or Maps app.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMap = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nearby Pharmacies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Detect Location',
            onPressed: _detectLocation,
          ),
        ],
      ),
      body: !_isEntitled ? _buildLockedView() : _buildContent(),
    );
  }

  Widget _buildLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              'MediTrack Premium Required',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Subscribe to MediTrack Premium to unlock nearby pharmacy directions, AI prescription scanning, and smart price lookups.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _checkEntitlementAndDetectLocation,
              child: const Text('Unlock Premium'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _detectLocation,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildLocationStatusCard(),
          const SizedBox(height: 16),
          _buildHeroMapsCard(),
          const SizedBox(height: 24),
          Text(
            'Quick Categories',
            style: AppTypography.headingSmall,
          ),
          const SizedBox(height: 12),
          ..._categories.map(_buildCategoryCard),
          const SizedBox(height: 24),
          _buildFeaturesCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLocationStatusCard() {
    if (_isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryGreen,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Detecting device GPS location...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_currentPosition != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GPS Location Active',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_currentPosition!.latitude.toStringAsFixed(4)}° N, ${_currentPosition!.longitude.toStringAsFixed(4)}° E',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _detectLocation,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Refresh', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // Handle failure reasons with clear, actionable UI
    String title = 'GPS Unavailable';
    String description = 'Google Maps will search your general area.';
    Widget? actionButton;

    switch (_failureReason) {
      case LocationFailureReason.serviceDisabled:
        title = 'Location Services Off';
        description = 'Turn on device location for exact GPS coordinates.';
        actionButton = TextButton(
          onPressed: () async {
            await _pharmacyService.openLocationSettings();
            _detectLocation();
          },
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.primaryGreen,
          ),
          child: const Text('Turn On', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
        break;
      case LocationFailureReason.permissionDenied:
        title = 'Permission Denied';
        description = 'Allow location permission to pinpoint nearby pharmacies.';
        actionButton = TextButton(
          onPressed: _detectLocation,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.primaryGreen,
          ),
          child: const Text('Allow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
        break;
      case LocationFailureReason.permissionDeniedForever:
        title = 'Permission Blocked';
        description = 'Location permission is permanently denied in settings.';
        actionButton = TextButton(
          onPressed: () async {
            await _pharmacyService.openAppSettings();
            _detectLocation();
          },
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.primaryGreen,
          ),
          child: const Text('Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
        break;
      case LocationFailureReason.timeoutOrUnavailable:
      default:
        title = 'GPS Fix Pending / Emulator';
        description = 'No satellite fix yet. Maps can still search your area.';
        actionButton = TextButton(
          onPressed: _useDhakaCoordinates,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.primaryGreen,
          ),
          child: const Text('Use Dhaka', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_outlined,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actionButton,
        ],
      ),
    );
  }

  Widget _buildHeroMapsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: AppColors.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Google Maps Search',
                      style: AppTypography.headingSmall.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time pins, opening hours & directions',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Explore pharmacies around your current position on Google Maps with verified reviews, contact numbers, and turn-by-turn navigation.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isOpeningMap ? null : () => _launchMapsSearch(query: 'pharmacy'),
              icon: _isOpeningMap
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.explore_rounded, size: 20),
              label: Text(
                _isOpeningMap ? 'Opening Maps...' : 'Find Pharmacies on Google Maps',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(_PharmacyCategory category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isOpeningMap ? null : () => _launchMapsSearch(query: category.query),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: AppTypography.headingSmall.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.subtitle,
                      style: AppTypography.bodySmall.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Information on Google Maps',
            style: AppTypography.headingSmall.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: Icons.schedule_rounded,
            title: 'Live Opening Hours',
            description: 'Check if the pharmacy is open now or 24/7 before traveling.',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _buildFeatureItem(
            icon: Icons.directions_car_rounded,
            title: 'Live Navigation & Traffic',
            description: 'Get real-time driving, transit, and walking route estimates.',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _buildFeatureItem(
            icon: Icons.call_rounded,
            title: 'Direct Phone Calling',
            description: 'Call the pharmacy directly to verify medicine availability.',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _buildFeatureItem(
            icon: Icons.star_rounded,
            title: 'Ratings & Reviews',
            description: 'Read feedback from other local customers.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PharmacyCategory {
  final String title;
  final String subtitle;
  final String query;
  final IconData icon;
  final Color color;

  const _PharmacyCategory({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.icon,
    required this.color,
  });
}
