import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../logic/entitlement_guard.dart';
import '../services/pharmacy_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/premium_gate.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';

class NearbyPharmaciesScreen extends StatefulWidget {
  const NearbyPharmaciesScreen({super.key});

  @override
  State<NearbyPharmaciesScreen> createState() => _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState extends State<NearbyPharmaciesScreen> {
  final PharmacyService _pharmacyService = PharmacyService();

  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  String _selectedCity = 'Dhaka';

  final List<String> _bdCities = [
    'Dhaka',
    'Chittagong',
    'Sylhet',
    'Rajshahi',
    'Khulna',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final pos = await _pharmacyService.getCurrentPosition();
      setState(() => _currentPosition = pos);
    } catch (e) {
      setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _launchMaps(String query) async {
    try {
      final launched = await _pharmacyService.openNearbyPharmaciesInMaps(
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        query: _currentPosition != null
            ? query
            : '$query $_selectedCity Bangladesh',
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps app')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching Maps: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGate(
      feature: EntitlementFeature.nearbyPharmacy,
      builder: _buildScreen,
    );
  }

  Widget _buildScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Nearby Pharmacies'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // GPS Location Status Card
          _buildLocationStatusCard(isDark),
          const SizedBox(height: 18),

          // Bangladesh City Preset Chips
          _buildCitySelector(isDark),
          const SizedBox(height: 24),

          // Primary Maps Launch Card
          _buildHeroMapsCard(isDark),
          const SizedBox(height: 24),

          // Categorized Quick Searches
          const SectionHeader(
            title: 'Pharmacy Categories',
            subtitle: 'Find specialized medical dispensaries in Bangladesh',
          ),
          _buildCategoryCard(
            title: '24-Hour Emergency Pharmacies',
            subtitle:
                'Find open overnight pharmacies and critical medicine dispensaries',
            icon: Icons.access_time_filled_rounded,
            color: AppColors.accentPink,
            onTap: () => _launchMaps('24 hour pharmacy'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            title: 'Hospital & Model Pharmacies',
            subtitle:
                'Verified government model pharmacies & hospital dispensaries',
            icon: Icons.local_hospital_rounded,
            color: AppColors.primaryBlue,
            onTap: () => _launchMaps('model pharmacy hospital'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            title: 'Medicine & Surgical Stores',
            subtitle:
                'Retail chemist shops, first aid supplies & surgical goods',
            icon: Icons.medical_services_rounded,
            color: AppColors.accentOrange,
            onTap: () => _launchMaps('medicine store chemist'),
            isDark: isDark,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLocationStatusCard(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _currentPosition != null
                  ? AppColors.successLight
                  : AppColors.primaryBlueLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentPosition != null
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              color: _currentPosition != null
                  ? AppColors.success
                  : AppColors.primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentPosition != null
                      ? 'GPS Location Active'
                      : (_isLoadingLocation
                            ? 'Locating device...'
                            : 'Location Not Detected'),
                  style: AppTypography.headingSmall.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentPosition != null
                      ? 'Using real-time coordinates (${_currentPosition!.latitude.toStringAsFixed(3)}, ${_currentPosition!.longitude.toStringAsFixed(3)})'
                      : (_locationError ??
                            'Defaulting to $_selectedCity center.'),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          SoftIconButton(
            icon: Icons.refresh_rounded,
            size: 36,
            iconSize: 18,
            iconColor: AppColors.primaryBlue,
            tooltip: 'Refresh Location',
            onPressed: _isLoadingLocation ? null : _fetchCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildCitySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Bangladesh City / Region',
          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _bdCities.map((city) {
              final isSelected = _selectedCity == city;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(city),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlueLight,
                  labelStyle: AppTypography.caption.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryBlue : null,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCity = city);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroMapsCard(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(20),
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Google Maps',
                      style: AppTypography.headingMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Turn-by-turn navigation, store hours, and contact numbers',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SoftPrimaryButton(
            label: 'Search Nearest Pharmacies',
            icon: Icons.directions_rounded,
            onPressed: () => _launchMaps('pharmacy'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return SoftSurface(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
