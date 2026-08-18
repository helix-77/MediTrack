import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../models/user_profile.dart';
import '../models/family_member.dart';
import '../services/medicine_service.dart';
import '../services/user_profile_service.dart';
import '../services/family_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import 'add_edit_medicine_screen.dart';
import 'medicine_detail_screen.dart';
import 'prescription_vault_screen.dart';
import 'scan_prescription_screen.dart';
import 'calendar_routine_screen.dart';
import 'medicine_search_screen.dart';
import 'nearby_pharmacies_screen.dart';
import 'doctor_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MedicineService _medicineService = MedicineService();
  final UserProfileService _profileService = UserProfileService();
  final FamilyService _familyService = FamilyService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFamilyMemberId; // null = all, 'self' = self, or member.id

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreetingSubtitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: _profileService.streamProfile(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            final displayName = profile?.displayName ?? 'User';

            return StreamBuilder<List<Medicine>>(
              stream: _medicineService.streamMedicines(),
              builder: (context, medSnapshot) {
                final allMedicines = medSnapshot.data ?? [];
                var filteredMedicines = allMedicines;
                if (_selectedFamilyMemberId == 'self') {
                  filteredMedicines = filteredMedicines
                      .where((m) => m.familyMemberId == null)
                      .toList();
                } else if (_selectedFamilyMemberId != null) {
                  filteredMedicines = filteredMedicines
                      .where((m) => m.familyMemberId == _selectedFamilyMemberId)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filteredMedicines = filteredMedicines
                      .where(
                        (m) => m.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                }

                final lowStockMedicines = allMedicines
                    .where(
                      (m) => RefillCalculator.isLowStock(
                        m.quantityCurrent,
                        m.lowStockThreshold,
                      ),
                    )
                    .toList();
                final expiringMedicines = allMedicines
                    .where((m) => RefillCalculator.isExpiringSoon(m.expiryDate))
                    .toList();

                return StreamBuilder<List<DoseLog>>(
                  stream: _medicineService.streamTodayDoseLogs(),
                  builder: (context, logSnapshot) {
                    final todayLogs = logSnapshot.data ?? [];
                    final doseItems = _generateTodayDoseItems(
                      filteredMedicines,
                      todayLogs,
                    );

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      children: [
                        // Top Header Bar
                        _buildTopHeaderBar(displayName, isDark),
                        const SizedBox(height: 16),

                        // Greeting Header
                        _buildGreetingHeader(displayName, isDark),
                        const SizedBox(height: 16),

                        // Search Bar
                        _buildSearchBar(isDark),
                        const SizedBox(height: 20),

                        // Welcome Hero Card Banner
                        _buildWelcomeHeroBanner(isDark),
                        const SizedBox(height: 18),

                        // Family Filter Chips
                        _buildFamilyFilterChips(isDark),
                        const SizedBox(height: 20),

                        // Ongoing Routine Section
                        SectionHeader(
                          title: 'Ongoing Routine',
                          subtitle: 'Today\'s 4 scheduled intake time slots',
                          actionLabel: 'Calendar View →',
                          onActionTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CalendarRoutineScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),

                        // 2-Column Grid for Dose Cards
                        if (doseItems.isEmpty)
                          const EmptyStateView(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'No Doses Scheduled Today',
                            description: 'Tap the + button at the bottom to add a medicine to your daily schedule.',
                          )
                        else
                          _buildDoseGrid(doseItems, isDark),

                        const SizedBox(height: 28),

                        // Low Stock Alert Section
                        if (lowStockMedicines.isNotEmpty) ...[
                          const SectionHeader(
                            title: 'Low Stock Alerts',
                            subtitle: 'Medicines nearing depletion threshold',
                          ),
                          _buildLowStockList(lowStockMedicines, isDark),
                          const SizedBox(height: 24),
                        ],

                        // Expiring Soon Section
                        if (expiringMedicines.isNotEmpty) ...[
                          const SectionHeader(
                            title: 'Expiring Soon',
                            subtitle: 'Medicines approaching expiration date',
                          ),
                          _buildExpiringSoonList(expiringMedicines, isDark),
                          const SizedBox(height: 24),
                        ],

                        // All Prescriptions / Inventory Section
                        SectionHeader(
                          title: 'My Inventory',
                          subtitle: '${allMedicines.length} active medicines tracked',
                        ),
                        _buildAllPrescriptionsSection(allMedicines, isDark),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHeaderBar(String displayName, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SoftIconButton(
          icon: Icons.grid_view_rounded,
          size: 42,
          iconColor: AppColors.primaryBlue,
          onPressed: () {},
        ),
        Text(
          'MediTrack',
          style: AppTypography.headingSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        SoftIconButton(
          icon: Icons.notifications_none_rounded,
          size: 42,
          hasBadge: true,
          iconColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildGreetingHeader(String displayName, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $displayName 👋',
          style: AppTypography.displayLarge.copyWith(
            fontSize: 26,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${_getGreetingSubtitle()} • Let\'s stay on top of your health today.',
          style: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return SoftSurface(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(30),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search medicines or prescriptions...',
          hintStyle: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.primaryBlue,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: false,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeroBanner(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: AppRadii.cardRadius,
      borderColor: isDark ? AppColors.darkDivider : AppColors.primaryBlue.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Health Tools',
                      style: AppTypography.headingMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI prescription scanning, MRP generic search & 24/7 pharmacies',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryBlue,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SoftPrimaryButton(
                  label: 'Scan Rx',
                  icon: Icons.document_scanner_rounded,
                  height: 44,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScanPrescriptionScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftSecondaryButton(
                  label: 'Rx Vault',
                  icon: Icons.folder_shared_outlined,
                  height: 44,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrescriptionVaultScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  icon: Icons.search_rounded,
                  label: 'Price & Generic Lookup',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MedicineSearchScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  icon: Icons.local_pharmacy_outlined,
                  label: 'Nearby Pharmacies',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NearbyPharmaciesScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Doctor Summary',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DoctorSummaryScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryBlue),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyFilterChips(bool isDark) {
    return StreamBuilder<List<FamilyMember>>(
      stream: _familyService.streamFamilyMembers(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const SizedBox.shrink();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChipItem(
                label: 'All Medicines',
                isSelected: _selectedFamilyMemberId == null,
                onSelected: () => setState(() => _selectedFamilyMemberId = null),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChipItem(
                label: 'Myself',
                isSelected: _selectedFamilyMemberId == 'self',
                onSelected: () => setState(() => _selectedFamilyMemberId = 'self'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              ...members.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildFilterChipItem(
                    label: m.displayName,
                    isSelected: _selectedFamilyMemberId == m.id,
                    onSelected: () {
                      setState(() {
                        _selectedFamilyMemberId = _selectedFamilyMemberId == m.id ? null : m.id;
                      });
                    },
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChipItem({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : (isDark ? AppColors.darkDivider : AppColors.divider),
            width: 0.8,
          ),
          boxShadow: isSelected ? AppShadows.subtle : [],
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDoseGrid(List<_DoseItem> doseItems, bool isDark) {
    final morningDoses = <_DoseItem>[];
    final noonDoses = <_DoseItem>[];
    final eveningDoses = <_DoseItem>[];
    final nightDoses = <_DoseItem>[];

    for (var item in doseItems) {
      final parts = item.timeString.split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      if (hour >= 5 && hour < 12) {
        morningDoses.add(item);
      } else if (hour >= 12 && hour < 17) {
        noonDoses.add(item);
      } else if (hour >= 17 && hour < 21) {
        eveningDoses.add(item);
      } else {
        nightDoses.add(item);
      }
    }

    final slots = [
      _TimeSlotData(
        title: 'Morning',
        timeRange: '5:00 AM - 11:59 AM',
        icon: Icons.wb_sunny_rounded,
        accentColor: AppColors.accentOrange,
        bgColor: isDark ? const Color(0xFF242017) : AppColors.accentOrangeLight,
        doses: morningDoses,
      ),
      _TimeSlotData(
        title: 'Noon',
        timeRange: '12:00 PM - 4:59 PM',
        icon: Icons.wb_sunny_outlined,
        accentColor: AppColors.primaryBlue,
        bgColor: isDark ? const Color(0xFF17202B) : AppColors.primaryBlueLight,
        doses: noonDoses,
      ),
      _TimeSlotData(
        title: 'Evening',
        timeRange: '5:00 PM - 8:59 PM',
        icon: Icons.wb_twilight_rounded,
        accentColor: AppColors.accentPink,
        bgColor: isDark ? const Color(0xFF2B1824) : AppColors.accentPinkLight,
        doses: eveningDoses,
      ),
      _TimeSlotData(
        title: 'Night',
        timeRange: '9:00 PM - 4:59 AM',
        icon: Icons.bedtime_rounded,
        accentColor: const Color(0xFF64748B),
        bgColor: isDark ? const Color(0xFF1E242F) : const Color(0xFFF1F5F9),
        doses: nightDoses,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.36,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        return _buildTimeSlotGridCard(slots[index], isDark);
      },
    );
  }

  Widget _buildTimeSlotGridCard(_TimeSlotData slot, bool isDark) {
    final total = slot.doses.length;
    final taken = slot.doses
        .where((d) => d.log.status == DoseStatus.taken)
        .length;
    final progress = total == 0 ? 0.0 : taken / total;

    String subtitleText = 'No doses scheduled';
    if (total > 0) {
      final names = slot.doses.map((d) => d.medicine.name).toSet().join(', ');
      subtitleText = '$total dose(s) • $names';
    }

    return SoftSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: AppRadii.cardRadius,
      color: slot.bgColor,
      borderColor: slot.accentColor.withValues(alpha: 0.25),
      onTap: () => _openTimeSlotDetailModal(slot),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: slot.accentColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(slot.icon, color: slot.accentColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    slot.title,
                    style: AppTypography.headingSmall.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              StatusPill(
                label: '$taken/$total',
                customBgColor: slot.accentColor.withValues(alpha: 0.15),
                customTextColor: slot.accentColor,
              ),
            ],
          ),
          Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: slot.accentColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(slot.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  void _openTimeSlotDetailModal(_TimeSlotData slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(slot.icon, color: slot.accentColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${slot.title} Routine',
                  style: AppTypography.headingMedium,
                ),
                const Spacer(),
                Text(
                  slot.timeRange,
                  style: AppTypography.caption,
                ),
              ],
            ),
            const Divider(height: 24),
            if (slot.doses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No doses scheduled for ${slot.title.toLowerCase()}',
                    style: AppTypography.bodySmall,
                  ),
                ),
              )
            else
              ...slot.doses.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.log.status == DoseStatus.taken
                        ? Icons.check_circle_rounded
                        : Icons.medication_rounded,
                    color: item.log.status == DoseStatus.taken
                        ? AppColors.success
                        : slot.accentColor,
                  ),
                  title: Text(
                    item.medicine.name,
                    style: AppTypography.headingSmall,
                  ),
                  subtitle: Text(
                    '${TimeFormatter.format24To12Hour(item.timeString)} • ${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit"}',
                    style: AppTypography.caption,
                  ),
                  trailing: item.log.status == DoseStatus.taken
                      ? const StatusPill(
                          label: 'Taken',
                          type: PillType.success,
                        )
                      : SoftPrimaryButton(
                          label: 'Take',
                          height: 36,
                          width: 80,
                          backgroundColor: slot.accentColor,
                          onPressed: () async {
                            Navigator.pop(context);
                            await _medicineService.updateDoseStatus(
                              logId: item.log.id,
                              medicineId: item.medicine.id,
                              medicineName: item.medicine.name,
                              status: DoseStatus.taken,
                              doseAmount: item.medicine.schedule.doseAmount,
                              scheduledAt: item.log.scheduledAt,
                            );
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Medicine medicine) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Delete Medicine', style: AppTypography.headingMedium),
        content: Text(
          'Are you sure you want to delete "${medicine.name}"? This will delete the entire prescription and all scheduled doses.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _medicineService.deleteMedicine(medicine.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockList(List<Medicine> medicines, bool isDark) {
    return Column(
      children: medicines
          .map(
            (m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: SoftSurface(
                padding: const EdgeInsets.all(14),
                color: isDark ? const Color(0xFF2B2215) : AppColors.warningLight,
                borderColor: AppColors.warning.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: AppTypography.headingSmall),
                          const SizedBox(height: 2),
                          Text(
                            'Stock: ${m.quantityCurrent} left (Threshold: ${m.lowStockThreshold})',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    SoftPrimaryButton(
                      label: 'Refill',
                      height: 34,
                      width: 76,
                      backgroundColor: AppColors.warning,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditMedicineScreen(medicine: m),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildExpiringSoonList(List<Medicine> medicines, bool isDark) {
    return Column(
      children: medicines
          .map(
            (m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: SoftSurface(
                padding: const EdgeInsets.all(14),
                color: isDark ? const Color(0xFF2D1818) : AppColors.dangerLight,
                borderColor: AppColors.danger.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: AppTypography.headingSmall),
                          const SizedBox(height: 2),
                          Text(
                            'Expires: ${m.expiryDate != null ? DateFormat('yyyy-MM-dd').format(m.expiryDate!) : "N/A"}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAllPrescriptionsSection(List<Medicine> medicines, bool isDark) {
    if (medicines.isEmpty) {
      return const EmptyStateView(
        icon: Icons.medication_liquid_outlined,
        title: 'No Medicines Added Yet',
        description: 'Keep your health organized by tracking dosages, times, and stock.',
      );
    }

    return Column(
      children: medicines
          .map(
            (m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: SoftSurface(
                padding: const EdgeInsets.all(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicineDetailScreen(medicineId: m.id),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlueLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_liquid_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: AppTypography.headingSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${m.schedule.doseTimes.length} dose(s)/day (${m.schedule.doseTimes.map(TimeFormatter.format24To12Hour).join(', ')})',
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusPill(
                          label: '${m.quantityCurrent} left',
                          type: PillType.primary,
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      onPressed: () => _showDeleteConfirmationDialog(m),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<_DoseItem> _generateTodayDoseItems(
    List<Medicine> medicines,
    List<DoseLog> todayLogs,
  ) {
    final List<_DoseItem> items = [];
    final today = DateTime.now();
    final weekday = today.weekday;

    for (var med in medicines) {
      if (!med.schedule.active) continue;
      if (!med.schedule.daysOfWeek.contains(weekday)) continue;

      for (var time in med.schedule.doseTimes) {
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;
        final scheduledDateTime = DateTime(
          today.year,
          today.month,
          today.day,
          hour,
          minute,
        );

        final matchingLog = todayLogs.firstWhere(
          (l) =>
              l.medicineId == med.id &&
              _isSameDay(l.scheduledAt, today) &&
              DateFormat('HH:mm').format(l.scheduledAt) == time,
          orElse: () => DoseLog(
            id: '',
            medicineId: med.id,
            medicineName: med.name,
            scheduledAt: scheduledDateTime,
            status: DoseStatus.pending,
          ),
        );

        items.add(_DoseItem(medicine: med, log: matchingLog, timeString: time));
      }
    }

    items.sort((a, b) => a.timeString.compareTo(b.timeString));
    return items;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DoseItem {
  final Medicine medicine;
  final DoseLog log;
  final String timeString;

  _DoseItem({
    required this.medicine,
    required this.log,
    required this.timeString,
  });
}

class _TimeSlotData {
  final String title;
  final String timeRange;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final List<_DoseItem> doses;

  _TimeSlotData({
    required this.title,
    required this.timeRange,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.doses,
  });
}
