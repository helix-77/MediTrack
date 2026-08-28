import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/family_member.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../services/family_service.dart';
import '../services/family_filter_notifier.dart';
import '../services/medicine_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import 'medicine_detail_screen.dart';

class CalendarRoutineScreen extends StatefulWidget {
  const CalendarRoutineScreen({super.key});

  @override
  State<CalendarRoutineScreen> createState() => _CalendarRoutineScreenState();
}

class _CalendarRoutineScreenState extends State<CalendarRoutineScreen> {
  final MedicineService _medicineService = MedicineService();
  final FamilyService _familyService = FamilyService();
  late final ScrollController _dateScrollController;

  late final DateTime _startDate;
  late final int _totalDays;
  DateTime _selectedDate = DateTime.now();

  static const double _itemWidth = 58.0;
  static const double _itemMargin = 8.0;
  static const double _totalItemWidth = _itemWidth + _itemMargin;

  int _daysBetween(DateTime from, DateTime to) {
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }

  DateTime _getDateForIndex(int index) {
    return DateTime(_startDate.year, _startDate.month, _startDate.day + index);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedDate = today;
    _startDate = DateTime(today.year, today.month, today.day - 90);
    final endDate = DateTime(today.year, today.month, today.day + 90);
    _totalDays = _daysBetween(_startDate, endDate) + 1;

    final initialIndex = _daysBetween(_startDate, _selectedDate);
    const estimatedViewportWidth = 360.0;
    final initialOffset = ((initialIndex * _totalItemWidth) + (_itemWidth / 2) - (estimatedViewportWidth / 2))
        .clamp(0.0, double.infinity);
    _dateScrollController = ScrollController(initialScrollOffset: initialOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(_selectedDate, animate: false);
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToDate(DateTime date, {bool animate = true}) {
    if (!_dateScrollController.hasClients) return;
    final index = _daysBetween(_startDate, date);
    if (index < 0 || index >= _totalDays) return;

    final screenWidth = MediaQuery.of(context).size.width - 40;
    final targetOffset = (index * _totalItemWidth) + (_itemWidth / 2) - (screenWidth / 2);
    final maxScroll = _dateScrollController.position.maxScrollExtent;
    final clampedOffset = maxScroll > 0
        ? targetOffset.clamp(0.0, maxScroll)
        : (targetOffset < 0 ? 0.0 : targetOffset);

    if (animate) {
      _dateScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _dateScrollController.jumpTo(clampedOffset);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _startDate,
      lastDate: _getDateForIndex(_totalDays - 1),
    );
    if (picked != null) {
      final normalizedPicked = DateTime(picked.year, picked.month, picked.day);
      setState(() => _selectedDate = normalizedPicked);
      _scrollToDate(normalizedPicked, animate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final familyFilter = context.watch<FamilyFilterNotifier>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'Routine Dashboard',
          style: AppTypography.headingMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SoftIconButton(
              icon: Icons.calendar_month_rounded,
              iconColor: AppColors.primaryBlue,
              size: 40,
              tooltip: 'Pick Date',
              onPressed: _pickCustomDate,
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: _medicineService.streamMedicines(),
        builder: (context, medSnapshot) {
          if (medSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            );
          }

          final allMedicines = medSnapshot.data ?? [];
          final medicines = allMedicines
              .where((m) => m.familyMemberId == familyFilter.currentFamilyMemberId)
              .toList();

          return StreamBuilder<List<DoseLog>>(
            stream: _medicineService.streamDateDoseLogs(_selectedDate),
            builder: (context, logSnapshot) {
              final logs = logSnapshot.data ?? [];
              final dayItems = _generateDayDoseItems(medicines, logs, _selectedDate);

              final totalDoses = dayItems.length;
              final takenDoses = dayItems.where((i) => i.log.status == DoseStatus.taken).length;
              final progress = totalDoses == 0 ? 0.0 : takenDoses / totalDoses;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Family Member Filter Chips
                  _buildFamilyFilterChips(familyFilter, isDark),

                  // Date Bar Selector
                  _buildDateSelectorBar(isDark),
                  const SizedBox(height: 18),

                  // Daily Intake Progress Card
                  _buildProgressCard(takenDoses, totalDoses, progress, isToday, isDark),
                  const SizedBox(height: 24),

                  // Routine Timeline Section Header
                  SectionHeader(
                    title: 'Scheduled Timeline',
                    subtitle: DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                    trailing: StatusPill(
                      label: '$totalDoses dose(s)',
                      type: PillType.primary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (dayItems.isEmpty)
                    EmptyStateView(
                      icon: Icons.calendar_today_rounded,
                      title: 'No Doses Scheduled',
                      description: 'No active medicine doses are scheduled for ${DateFormat('EEE, MMM d').format(_selectedDate)}.',
                    )
                  else
                    ...dayItems.map((item) => _buildTimelineDoseCard(item, isDark)),
                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFamilyFilterChips(FamilyFilterNotifier familyFilter, bool isDark) {
    return StreamBuilder<List<FamilyMember>>(
      stream: _familyService.streamFamilyMembers(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChipItem(
                  label: 'Myself',
                  isSelected: familyFilter.isSelf,
                  onSelected: () => familyFilter.selectSelf(),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                ...members.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildFilterChipItem(
                      label: m.displayName,
                      isSelected: familyFilter.selectedMemberId == m.id,
                      onSelected: () => familyFilter.selectMember(m.id),
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
          boxShadow: isSelected
              ? AppShadows.subtle
              : [
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
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelectorBar(bool isDark) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _totalDays,
        itemBuilder: (context, index) {
          final date = _getDateForIndex(index);
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _scrollToDate(date, animate: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _itemWidth,
              margin: const EdgeInsets.only(right: _itemMargin),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark ? AppColors.darkSurface : AppColors.surface),
                borderRadius: BorderRadius.circular(18),
                border: isToday && !isSelected
                    ? Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
                boxShadow: isSelected
                    ? AppShadows.subtle
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white70
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: AppTypography.headingSmall.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard(int taken, int total, double progress, bool isToday, bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: AppRadii.cardRadius,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'Today\'s Intake Progress' : DateFormat('EEEE, MMM d').format(_selectedDate),
                    style: AppTypography.headingSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              StatusPill(
                label: '$taken / $total',
                type: progress >= 1.0 ? PillType.success : PillType.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkDivider : AppColors.primaryBlueLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDoseCard(_RoutineDoseItem item, bool isDark) {
    final isTaken = item.log.status == DoseStatus.taken;
    final isSkipped = item.log.status == DoseStatus.skipped;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SoftSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MedicineDetailScreen(medicineId: item.medicine.id),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isTaken
                    ? (isDark ? AppColors.success.withValues(alpha: 0.18) : AppColors.successLight)
                    : (isSkipped
                        ? (isDark ? AppColors.danger.withValues(alpha: 0.18) : AppColors.dangerLight)
                        : (isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTaken ? Icons.check : (isSkipped ? Icons.close : Icons.schedule),
                size: 18,
                color: isTaken
                    ? AppColors.success
                    : (isSkipped ? AppColors.danger : AppColors.primaryBlue),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.medicine.name} (${TimeFormatter.format24To12Hour(item.timeString)})',
                    style: AppTypography.headingSmall.copyWith(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit(s)"} • ${TimeFormatter.formatDaysOfWeek(item.medicine.schedule.daysOfWeek)}',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isTaken)
              const StatusPill(
                label: 'Taken',
                type: PillType.success,
              )
            else
              SoftIconButton(
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.primaryBlue,
                size: 38,
                iconSize: 22,
                onPressed: () {
                  _medicineService.updateDoseStatus(
                    logId: item.log.id,
                    medicineId: item.medicine.id,
                    medicineName: item.medicine.name,
                    status: DoseStatus.taken,
                    doseAmount: item.medicine.schedule.doseAmount,
                    scheduledAt: item.log.scheduledAt,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<_RoutineDoseItem> _generateDayDoseItems(List<Medicine> medicines, List<DoseLog> logs, DateTime date) {
    final List<_RoutineDoseItem> items = [];
    final weekday = date.weekday;

    for (var med in medicines) {
      if (!med.schedule.active) continue;
      if (!med.schedule.daysOfWeek.contains(weekday)) continue;

      for (var time in med.schedule.doseTimes) {
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts[1]) ?? 0;
        final scheduledDateTime = DateTime(date.year, date.month, date.day, hour, minute);

        final matchingLog = logs.firstWhere(
          (l) => l.medicineId == med.id && _isSameDay(l.scheduledAt, date) && DateFormat('HH:mm').format(l.scheduledAt) == time,
          orElse: () => DoseLog(
            id: '',
            medicineId: med.id,
            medicineName: med.name,
            scheduledAt: scheduledDateTime,
            status: DoseStatus.pending,
          ),
        );

        items.add(_RoutineDoseItem(medicine: med, log: matchingLog, timeString: time));
      }
    }

    items.sort((a, b) => a.timeString.compareTo(b.timeString));
    return items;
  }
}

class _RoutineDoseItem {
  final Medicine medicine;
  final DoseLog log;
  final String timeString;

  _RoutineDoseItem({
    required this.medicine,
    required this.log,
    required this.timeString,
  });
}
