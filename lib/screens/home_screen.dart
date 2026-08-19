import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../models/user_profile.dart';
import '../models/family_member.dart';
import '../services/avatar_service.dart';
import '../services/routine_schedule_service.dart';
import '../services/medicine_service.dart';
import '../services/user_profile_service.dart';
import '../services/family_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import '../widgets/soft_modal_sheet.dart';
import 'prescription_vault_screen.dart';
import 'scan_prescription_screen.dart';
import 'calendar_routine_screen.dart';
import 'medicine_search_screen.dart';
import 'nearby_pharmacies_screen.dart';
import 'doctor_summary_screen.dart';
import 'profile_settings_screen.dart';
import 'buy_list_screen.dart';

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

                    final lowStockMedicines = filteredMedicines
                        .where((m) => RefillCalculator.isLowStock(m.quantityCurrent, m.lowStockThreshold))
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      children: [
                        // 1. Top Header: Greeting + Headline + Avatar
                        _buildTopHeader(
                          greeting: _getGreetingSubtitle(),
                          name: fullName,
                          initial: userInitial,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 18),

                        // Optional: Family Member Filters (if members exist)
                        _buildFamilyFilterChips(isDark),

                        // 2. Combined Hero Progress Card: "Today's Health & Overview"
                        _buildTodaysHealthCard(
                          completed: completedTodayDoses,
                          total: totalTodayDoses,
                          progress: todayProgressPercent,
                          adherenceRate: adherenceRate,
                          activeMedicinesCount: filteredMedicines.length,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 18),

                        // Contextual Low-Stock Alert Banner (if any running low)
                        if (lowStockMedicines.isNotEmpty) ...[
                          _buildLowStockRefillBanner(lowStockMedicines, isDark),
                        ],

                        // 3. "Smart Health Tools"
                        _buildSmartHealthToolsCard(isDark, lowStockCount: lowStockMedicines.length),
                        const SizedBox(height: 28),

                        // 4. "Ongoing Routine" (4 Time Slot Cards Grid)
                        _buildOngoingRoutineSection(
                          doseItems: doseItems,
                          isDark: isDark,
                        ),
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
                'Stay on top of your health',
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 22,
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
          child: Builder(
            builder: (context) {
              final avatarNotifier = context.watch<AvatarNotifier>();
              return Container(
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
                child: ClipOval(
                  child: avatarNotifier.avatarFile != null
                      ? Image.file(
                          avatarNotifier.avatarFile!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: AppTypography.headingMedium.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              );
            },
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
    required int adherenceRate,
    required int activeMedicinesCount,
    required bool isDark,
  }) {
    final percentInt = (progress * 100).round();
    final subtext = total == 0
        ? 'Add your active medications below'
        : '$completed of $total doses completed today';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.06 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, Message, & Circular Percentage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "TODAY'S HEALTH",
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
          const SizedBox(height: 16),

          // Clean Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0.0 : progress,
              minHeight: 7,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.85),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
          const SizedBox(height: 18),
        ]
      ),
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
    final schedule = context.watch<RoutineScheduleNotifier>();
    final morningDoses = <_DoseItem>[];
    final noonDoses = <_DoseItem>[];
    final eveningDoses = <_DoseItem>[];
    final nightDoses = <_DoseItem>[];

    for (var item in doseItems) {
      final slot = schedule.getSlotForTime(item.timeString);
      switch (slot) {
        case RoutineSlotType.morning:
          morningDoses.add(item);
          break;
        case RoutineSlotType.noon:
          noonDoses.add(item);
          break;
        case RoutineSlotType.evening:
          eveningDoses.add(item);
          break;
        case RoutineSlotType.night:
          nightDoses.add(item);
          break;
      }
    }

    final slots = [
      _TimeSlotData(
        title: 'Morning',
        timeRange: schedule.getMorningRange(),
        icon: Icons.wb_sunny_rounded,
        accentColor: const Color(0xFFF97316),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: morningDoses,
      ),
      _TimeSlotData(
        title: 'Noon',
        timeRange: schedule.getNoonRange(),
        icon: Icons.wb_twilight_rounded,
        accentColor: const Color(0xFFEC4899),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: noonDoses,
      ),
      _TimeSlotData(
        title: 'Evening',
        timeRange: schedule.getEveningRange(),
        icon: Icons.nights_stay_outlined,
        accentColor: const Color(0xFFA855F7),
        bgColor: isDark ? AppColors.darkSurface : Colors.white,
        doses: eveningDoses,
      ),
      _TimeSlotData(
        title: 'Night',
        timeRange: schedule.getNightRange(),
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
            childAspectRatio: 1.18,
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
    final countText = '$taken/$total';

    final cardBg = isDark
        ? Color.alphaBlend(slot.accentColor.withValues(alpha: 0.10), AppColors.darkSurface)
        : Color.alphaBlend(slot.accentColor.withValues(alpha: 0.06), Colors.white);

    return SoftSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      borderRadius: BorderRadius.circular(24),
      color: cardBg,
      onTap: () => _openTimeSlotDetailModal(slot),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular Icon Container inside the box
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? slot.accentColor.withValues(alpha: 0.20) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slot.accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              slot.icon,
              color: slot.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            slot.title,
            style: AppTypography.headingMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),

          // Dose Count (e.g. 10/14)
          Text(
            countText,
            style: AppTypography.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openTimeSlotDetailModal(_TimeSlotData slot) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Initial sort: pending doses first, taken doses at the bottom
    slot.doses.sort((a, b) {
      final aTaken = a.log.status == DoseStatus.taken ? 1 : 0;
      final bTaken = b.log.status == DoseStatus.taken ? 1 : 0;
      if (aTaken != bTaken) return aTaken.compareTo(bTaken);
      return a.timeString.compareTo(b.timeString);
    });

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.85,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: slot.accentColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(slot.icon, color: slot.accentColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${slot.title} Routine',
                          style: AppTypography.headingMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(slot.timeRange, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  SoftIconButton(
                    icon: Icons.close_rounded,
                    size: 36,
                    iconSize: 18,
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Dose List (Dynamic height: ~25-30% for empty, ~40-50% for few, up to 85% scrollable for many)
            if (slot.doses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20),
                child: Center(
                  child: Text(
                    'No doses scheduled for ${slot.title.toLowerCase()}',
                    style: AppTypography.bodySmall,
                  ),
                ),
              )
            else
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: slot.doses.length,
                  separatorBuilder: (context, index) => const Divider(height: 12),
                  itemBuilder: (listCtx, index) {
                    final item = slot.doses[index];
                    final isTaken = item.log.status == DoseStatus.taken;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isTaken
                                  ? AppColors.successLight
                                  : slot.accentColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTaken
                                  ? Icons.check_circle_rounded
                                  : Icons.medication_rounded,
                              color: isTaken ? AppColors.success : slot.accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.medicine.name,
                                  style: AppTypography.headingSmall.copyWith(
                                    decoration: isTaken ? TextDecoration.lineThrough : null,
                                    color: isTaken
                                        ? (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${TimeFormatter.format24To12Hour(item.timeString)} • ${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit"}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          isTaken
                              ? const StatusPill(label: 'Taken', type: PillType.success)
                              : SoftPrimaryButton(
                                  label: 'Take',
                                  height: 36,
                                  width: 80,
                                  backgroundColor: slot.accentColor,
                                  onPressed: () {
                                    setModalState(() {
                                      item.log = DoseLog(
                                        id: item.log.id,
                                        medicineId: item.log.medicineId,
                                        medicineName: item.log.medicineName,
                                        scheduledAt: item.log.scheduledAt,
                                        status: DoseStatus.taken,
                                        respondedAt: DateTime.now(),
                                      );
                                      // Dynamically move taken dose to bottom
                                      slot.doses.sort((a, b) {
                                        final aTaken = a.log.status == DoseStatus.taken ? 1 : 0;
                                        final bTaken = b.log.status == DoseStatus.taken ? 1 : 0;
                                        if (aTaken != bTaken) return aTaken.compareTo(bTaken);
                                        return a.timeString.compareTo(b.timeString);
                                      });
                                    });
                                    _handleTakeDose(item);
                                  },
                                ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTEXTUAL LOW-STOCK ALERT BANNER
  // ---------------------------------------------------------------------------
  Widget _buildLowStockRefillBanner(List<Medicine> lowStockMeds, bool isDark) {
    final count = lowStockMeds.length;
    final medNames = lowStockMeds
        .map((m) => '${m.name} (${m.quantityCurrent} left)')
        .take(3)
        .join(', ');
    final moreText = count > 3 ? ' +${count - 3} more' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1E10) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refill Alert ($count low stock)',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$medNames$moreText',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF7C2D12),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyListScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Buy List',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. "SMART HEALTH TOOLS" (Image 2 reference)
  // ---------------------------------------------------------------------------
  Widget _buildSmartHealthToolsCard(bool isDark, {int lowStockCount = 0}) {
    return SoftSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      color: isDark ? AppColors.darkSurface : Colors.white,
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Primary Actions Row (Scan Rx + Rx Vault)
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
          const SizedBox(height: 12),
          // Secondary Quick Action Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  icon: Icons.shopping_basket_outlined,
                  label: lowStockCount > 0 ? 'Buy List ($lowStockCount)' : 'Buy List',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BuyListScreen(),
                      ),
                    );
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.subtle,
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
  DoseLog log;
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
