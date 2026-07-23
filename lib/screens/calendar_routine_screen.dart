import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../services/medicine_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
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
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Routine Dashboard', style: AppTypography.headingLarge.copyWith(color: AppColors.primaryGreen)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
            tooltip: 'Pick Date',
            onPressed: _pickCustomDate,
          ),
        ],
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: _medicineService.streamMedicines(),
        builder: (context, medSnapshot) {
          if (medSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Date Bar Selector
                  _buildDateSelectorBar(),
                  const SizedBox(height: 16),

                  // Daily Intake Progress Card
                  _buildProgressCard(takenDoses, totalDoses, progress, isToday),
                  const SizedBox(height: 24),

                  // Routine Timeline Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scheduled Routine',
                        style: AppTypography.headingMedium,
                      ),
                      Chip(
                        label: Text('${dayItems.length} doses'),
                        backgroundColor: AppColors.accentPinkLight,
                        labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (dayItems.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No doses scheduled for ${DateFormat('EEE, MMM d').format(_selectedDate)}',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    ...dayItems.map((item) => _buildTimelineDoseCard(item)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDateSelectorBar() {
    final today = DateTime.now();
    final days = List.generate(14, (index) => today.subtract(Duration(days: 7 - index)));

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = _isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primaryGreen : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: AppTypography.headingSmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
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

  Widget _buildProgressCard(int taken, int total, double progress, bool isToday) {
    final percentage = (progress * 100).toInt();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryGreenLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday ? 'Today\'s Intake Progress' : DateFormat('EEEE, MMM d').format(_selectedDate),
                  style: AppTypography.headingMedium.copyWith(color: Colors.white),
                ),
                Text(
                  '$percentage%',
                  style: AppTypography.headingLarge.copyWith(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$taken of $total doses completed',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineDoseCard(_RoutineDoseItem item) {
    final isTaken = item.log.status == DoseStatus.taken;
    final isSkipped = item.log.status == DoseStatus.skipped;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isTaken
                ? AppColors.success.withValues(alpha: 0.15)
                : (isSkipped ? AppColors.textSecondary.withValues(alpha: 0.15) : AppColors.accentPinkLight),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isTaken ? Icons.check : (isSkipped ? Icons.close : Icons.schedule),
            color: isTaken ? AppColors.success : (isSkipped ? AppColors.textSecondary : AppColors.primaryGreen),
          ),
        ),
        title: Text(
          item.medicine.name,
          style: AppTypography.headingSmall.copyWith(
            decoration: isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${TimeFormatter.format24To12Hour(item.timeString)} • ${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit(s)"}',
          style: AppTypography.bodySmall,
        ),
        trailing: isTaken
            ? Chip(
                label: const Text('Taken'),
                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
              )
            : IconButton(
                icon: const Icon(Icons.check_circle_outline, color: AppColors.primaryGreen, size: 28),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MedicineDetailScreen(medicineId: item.medicine.id),
            ),
          );
        },
      ),
    );
  }

  List<_RoutineDoseItem> _generateDayDoseItems(List<Medicine> medicines, List<DoseLog> logs, DateTime date) {
    final List<_RoutineDoseItem> items = [];
    final weekday = date.weekday; // 1 = Mon, 7 = Sun

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
