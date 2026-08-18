import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
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
  DateTime _selectedDate = DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'Routine Dashboard',
          style: AppTypography.headingMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
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

          final medicines = medSnapshot.data ?? [];

          return StreamBuilder<List<DoseLog>>(
            stream: _medicineService.streamTodayDoseLogs(),
            builder: (context, logSnapshot) {
              final logs = logSnapshot.data ?? [];
              final dayItems = _generateDayDoseItems(medicines, logs, _selectedDate);

              final totalDoses = dayItems.length;
              final takenDoses = dayItems.where((i) => i.log.status == DoseStatus.taken).length;
              final progress = totalDoses == 0 ? 0.0 : takenDoses / totalDoses;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
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

  Widget _buildDateSelectorBar(bool isDark) {
    final today = DateTime.now();
    final days = List.generate(14, (index) => today.subtract(Duration(days: 7 - index)));

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = _isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark ? AppColors.darkSurface : AppColors.surface),
                borderRadius: BorderRadius.circular(18),
                boxShadow: isSelected ? AppShadows.subtle : [
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
    final percentage = (progress * 100).toInt();

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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$taken of $total doses completed',
                    style: AppTypography.caption,
                  ),
                ],
              ),
              StatusPill(
                label: '$percentage%',
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
                    ? AppColors.successLight
                    : (isSkipped ? AppColors.dangerLight : AppColors.primaryBlueLight),
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
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit(s)"} • ${TimeFormatter.formatDaysOfWeek(item.medicine.schedule.daysOfWeek)}',
                    style: AppTypography.caption,
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
