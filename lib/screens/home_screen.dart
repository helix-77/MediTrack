import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../models/user_profile.dart';
import '../models/family_member.dart';
import '../services/medicine_service.dart';
import '../services/user_profile_service.dart';
import '../services/family_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import 'prescription_vault_screen.dart';
import 'scan_prescription_screen.dart';
import 'calendar_routine_screen.dart';
import 'medicine_search_screen.dart';
import 'nearby_pharmacies_screen.dart';
import 'doctor_summary_screen.dart';
import 'profile_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MedicineService _medicineService = MedicineService();
  final UserProfileService _profileService = UserProfileService();
  final FamilyService _familyService = FamilyService();

  String? _selectedFamilyMemberId; // null = all, 'self' = self, or member.id

  String _getGreetingSubtitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
            final fullName = profile?.displayName.trim() ?? 'User';
            final firstName = fullName.split(' ').first;
            final userInitial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

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

                return StreamBuilder<List<DoseLog>>(
                  stream: _medicineService.streamTodayDoseLogs(),
                  builder: (context, logSnapshot) {
                    final todayLogs = logSnapshot.data ?? [];
                    final doseItems = _generateTodayDoseItems(
                      filteredMedicines,
                      todayLogs,
                    );

                    final totalTodayDoses = doseItems.length;
                    final completedTodayDoses = doseItems
                        .where((d) => d.log.status == DoseStatus.taken)
                        .length;
                    final todayProgressPercent = totalTodayDoses > 0
                        ? (completedTodayDoses / totalTodayDoses)
                        : 0.0;

                    // Adherence calculation (based on today's logs + active schedule)
                    final adherenceRate = totalTodayDoses > 0
                        ? ((completedTodayDoses / totalTodayDoses) * 100).round()
                        : 100;

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      children: [
                        // 1. Top Header: Greeting + Headline + Avatar
                        _buildTopHeader(
                          greeting: _getGreetingSubtitle(),
                          name: firstName,
                          initial: userInitial,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 18),

                        // Optional: Family Member Filters (if members exist)
                        _buildFamilyFilterChips(isDark),

                        // 2. Hero Progress Card: "Today's Health" (Image 1 reference)
                        _buildTodaysHealthCard(
                          completed: completedTodayDoses,
                          total: totalTodayDoses,
                          progress: todayProgressPercent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 22),

                        // 3. "Your health at a glance" (2 Stats Cards: Adherence & Active Medicines)
                        _buildHealthAtAGlanceSection(
                          adherenceRate: adherenceRate,
                          activeMedicinesCount: filteredMedicines.length,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 24),

                        // 4. "Ongoing Routine" (4 Time Slot Cards Grid - Image 2 reference)
                        _buildOngoingRoutineSection(
                          doseItems: doseItems,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 28),

                        // 5. "Smart Health Tools" (Image 2 reference)
                        _buildSmartHealthToolsCard(isDark),
                        const SizedBox(height: 36),
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

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader({
    required String greeting,
    required String name,
    required String initial,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $name',
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stay on top of your\nhealth',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // User Profile Avatar Bubble
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
            );
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0EDFE),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTypography.headingMedium.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. HERO PROGRESS CARD ("Today's Health")
  // ---------------------------------------------------------------------------
  Widget _buildTodaysHealthCard({
    required int completed,
    required int total,
    required double progress,
    required bool isDark,
  }) {
    final percentInt = (progress * 100).round();
    final encouragingText = total == 0
        ? 'No doses scheduled for today.'
        : (percentInt == 100
            ? 'All caught up! Fantastic job.'
            : (percentInt >= 50 ? 'You are doing great.' : 'Keep up the healthy habit.'));

    final subtext = total == 0
        ? 'Add your active medications below'
        : '$completed of $total doses completed today';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.05 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S HEALTH",
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      encouragingText,
                      style: AppTypography.headingMedium.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtext,
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Circular Percentage Badge
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$percentInt%',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Clean Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0.0 : progress,
              minHeight: 7,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.8),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. "YOUR HEALTH AT A GLANCE"
  // ---------------------------------------------------------------------------
  Widget _buildHealthAtAGlanceSection({
    required int adherenceRate,
    required int activeMedicinesCount,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your health at a glance',
          style: AppTypography.headingMedium.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Left Stat Card: Adherence
            Expanded(
              child: SoftSurface(
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(22),
                color: isDark ? AppColors.darkSurface : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0EDFE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Adherence',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$adherenceRate%',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Right Stat Card: Active Medicines
            Expanded(
              child: SoftSurface(
                padding: const EdgeInsets.all(18),
                borderRadius: BorderRadius.circular(22),
                color: isDark ? AppColors.darkSurface : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: Color(0xFFF59E0B),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Medicines',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activeMedicinesCount active',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }



  void _handleTakeDose(_DoseItem item) async {
    await _medicineService.updateDoseStatus(
      logId: item.log.id,
      medicineId: item.medicine.id,
      medicineName: item.medicine.name,
      status: DoseStatus.taken,
      doseAmount: item.medicine.schedule.doseAmount,
      scheduledAt: item.log.scheduledAt,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Recorded ${item.medicine.name} as taken!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 5. "ONGOING ROUTINE" (2x2 Time Slots Grid - Image 2 reference)
  // ---------------------------------------------------------------------------
  Widget _buildOngoingRoutineSection({
    required List<_DoseItem> doseItems,
    required bool isDark,
  }) {
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
        accentColor: const Color(0xFFF97316),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: morningDoses,
      ),
      _TimeSlotData(
        title: 'Noon',
        timeRange: '12:00 PM - 4:59 PM',
        icon: Icons.wb_twilight_rounded,
        accentColor: const Color(0xFFEC4899),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: noonDoses,
      ),
      _TimeSlotData(
        title: 'Evening',
        timeRange: '5:00 PM - 8:59 PM',
        icon: Icons.nights_stay_outlined,
        accentColor: const Color(0xFFA855F7),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: eveningDoses,
      ),
      _TimeSlotData(
        title: 'Night',
        timeRange: '9:00 PM - 4:59 AM',
        icon: Icons.nightlight_round,
        accentColor: const Color(0xFF3B82F6),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: nightDoses,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ongoing Routine',
              style: AppTypography.headingMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarRoutineScreen()),
                );
              },
              child: Text(
                'Calendar View →',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.88,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            return _buildTimeSlotGridCard(slots[index], isDark);
          },
        ),
      ],
    );
  }

  Widget _buildTimeSlotGridCard(_TimeSlotData slot, bool isDark) {
    final total = slot.doses.length;
    final taken = slot.doses.where((d) => d.log.status == DoseStatus.taken).length;

    String line1;
    if (total == 0) {
      line1 = 'No doses scheduled';
    } else if (taken == total) {
      line1 = 'All $total doses taken ✓';
    } else {
      line1 = '$taken of $total doses taken';
    }
    final line2 = slot.timeRange;

    return SoftSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      borderRadius: BorderRadius.circular(26),
      color: isDark ? AppColors.darkSurface : Colors.white,
      onTap: () => _openTimeSlotDetailModal(slot),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Icon Container matching reference design
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slot.accentColor.withValues(alpha: isDark ? 0.25 : 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: slot.accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  slot.icon,
                  color: slot.accentColor,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            slot.title,
            style: AppTypography.headingMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),

          // Subtitle
          Text(
            '$line1\n$line2',
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
                Text('${slot.title} Routine', style: AppTypography.headingMedium),
                const Spacer(),
                Text(slot.timeRange, style: AppTypography.caption),
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
                  title: Text(item.medicine.name, style: AppTypography.headingSmall),
                  subtitle: Text(
                    '${TimeFormatter.format24To12Hour(item.timeString)} • ${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit"}',
                    style: AppTypography.caption,
                  ),
                  trailing: item.log.status == DoseStatus.taken
                      ? const StatusPill(label: 'Taken', type: PillType.success)
                      : SoftPrimaryButton(
                          label: 'Take',
                          height: 36,
                          width: 80,
                          backgroundColor: slot.accentColor,
                          onPressed: () async {
                            Navigator.pop(context);
                            _handleTakeDose(item);
                          },
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. "SMART HEALTH TOOLS" (Smart Health Hub)
  // ---------------------------------------------------------------------------
  Widget _buildSmartHealthToolsCard(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Smart Health Tools',
              style: AppTypography.headingMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2A44) : AppColors.primaryBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    'AI Powered',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Featured AI Prescription Scanner Hero Card
        SoftSurface(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xFF162238) : const Color(0xFFEBF3FF),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ScanPrescriptionScreen(),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.document_scanner_rounded,
                    color: AppColors.primaryBlue,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Prescription Scanner',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Scan paper prescriptions to auto-extract medicines & dosage routines',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        height: 1.3,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4 Quick Health Tools (2x2 Grid)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.28,
          children: [
            _buildHealthToolTile(
              title: 'Rx Vault',
              subtitle: 'Archived prescriptions',
              icon: Icons.folder_shared_rounded,
              iconColor: const Color(0xFF0D9488),
              iconBgColor: const Color(0xFFE6FFFA),
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrescriptionVaultScreen()),
                );
              },
            ),
            _buildHealthToolTile(
              title: 'Generic & MRP',
              subtitle: 'DGDA price check',
              icon: Icons.medication_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBgColor: const Color(0xFFFEF3C7),
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicineSearchScreen()),
                );
              },
            ),
            _buildHealthToolTile(
              title: '24/7 Pharmacies',
              subtitle: 'Nearby store locator',
              icon: Icons.local_pharmacy_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBgColor: const Color(0xFFFEE2E2),
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NearbyPharmaciesScreen()),
                );
              },
            ),
            _buildHealthToolTile(
              title: 'Doctor Report',
              subtitle: 'Export visit summary',
              icon: Icons.assignment_rounded,
              iconColor: const Color(0xFF8B5CF6),
              iconBgColor: const Color(0xFFEDE9FE),
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthToolTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return SoftSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(22),
      color: isDark ? AppColors.darkSurface : Colors.white,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.4) : const Color(0xFF94A3B8),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headingSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAMILY FILTER CHIPS
  // ---------------------------------------------------------------------------
  Widget _buildFamilyFilterChips(bool isDark) {
    return StreamBuilder<List<FamilyMember>>(
      stream: _familyService.streamFamilyMembers(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: SingleChildScrollView(
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
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? AppShadows.subtle : [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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

  // ---------------------------------------------------------------------------
  // LOGIC HELPERS
  // ---------------------------------------------------------------------------
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
