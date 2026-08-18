import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../models/dose_log.dart';
import '../services/medicine_service.dart';
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

class MedicineDetailScreen extends StatefulWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final MedicineService _medicineService = MedicineService();

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Delete Medicine', style: AppTypography.headingMedium),
        content: Text(
          'Are you sure you want to delete this medicine record? This cannot be undone.',
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
              await _medicineService.deleteMedicine(widget.medicineId);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Medicine>>(
      stream: _medicineService.streamMedicines(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            ),
          );
        }

        final medicines = snapshot.data ?? [];
        final medicine = medicines.firstWhere(
          (m) => m.id == widget.medicineId,
          orElse: () => Medicine(
            id: '',
            name: 'Deleted',
            quantityCurrent: 0,
            quantityTotal: 0,
            schedule: MedicineSchedule(
              doseAmount: 0,
              timesPerDay: 0,
              doseTimes: [],
              daysOfWeek: [],
              startDate: DateTime.now(),
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (medicine.id.isEmpty) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
            appBar: AppBar(
              title: const Text('Medicine Details'),
              leading: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: SoftIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: 40,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            body: const EmptyStateView(
              icon: Icons.medication_outlined,
              title: 'Medicine Not Found',
              description: 'This record may have been deleted or moved.',
            ),
          );
        }

        final isLowStock = RefillCalculator.isLowStock(medicine.quantityCurrent, medicine.lowStockThreshold);
        final daysLeft = RefillCalculator.daysRemaining(medicine.quantityCurrent, medicine.schedule);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
          appBar: AppBar(
            title: Text(medicine.name),
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
                padding: const EdgeInsets.only(right: 8.0),
                child: SoftIconButton(
                  icon: Icons.edit_outlined,
                  size: 40,
                  iconColor: AppColors.primaryBlue,
                  tooltip: 'Edit Medicine',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddEditMedicineScreen(medicine: medicine)),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: SoftIconButton(
                  icon: Icons.delete_outline,
                  size: 40,
                  iconColor: AppColors.danger,
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Hero Stat Card
              SoftSurface(
                padding: const EdgeInsets.all(20),
                borderRadius: AppRadii.cardRadius,
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: AppTypography.displayLarge.copyWith(fontSize: 24),
                              ),
                              if (medicine.genericName != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  medicine.genericName!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatusPill(
                          label: medicine.dosageForm?.toUpperCase() ?? 'TABLET',
                          type: PillType.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('Stock Left', '${medicine.quantityCurrent} ${medicine.dosageForm ?? "units"}', isDark),
                        _buildStatItem('Est. Supply', '$daysLeft days', isDark),
                        _buildStatItem('Strength', medicine.strength ?? 'N/A', isDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Alert Cards if low stock
              if (isLowStock) ...[
                SoftSurface(
                  padding: const EdgeInsets.all(14),
                  color: isDark ? const Color(0xFF2B2215) : AppColors.warningLight,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Low Stock Warning',
                              style: AppTypography.headingSmall.copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Only ${medicine.quantityCurrent} units remaining. Plan a refill soon.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Schedule Info Card
              const SectionHeader(
                title: 'Schedule & Usage',
                subtitle: 'Prescribed dosage frequency and pack details',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildDetailRow('Dose Amount', '${medicine.schedule.doseAmount} ${medicine.dosageForm ?? "unit(s)"}', isDark),
                    const Divider(height: 18),
                    _buildDetailRow('Dose Times', medicine.schedule.doseTimes.map(TimeFormatter.format24To12Hour).join(", "), isDark),
                    const Divider(height: 18),
                    _buildDetailRow('Scheduled Days', TimeFormatter.formatDaysOfWeek(medicine.schedule.daysOfWeek), isDark),
                    const Divider(height: 18),
                    _buildDetailRow('Expiry Date', medicine.expiryDate != null ? DateFormat('yyyy-MM-dd').format(medicine.expiryDate!) : 'Not set', isDark),
                    if (medicine.batchNumber != null) ...[
                      const Divider(height: 18),
                      _buildDetailRow('Batch Number', medicine.batchNumber!, isDark),
                    ],
                    if (medicine.manufacturer != null) ...[
                      const Divider(height: 18),
                      _buildDetailRow('Manufacturer', medicine.manufacturer!, isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Dose History
              const SectionHeader(
                title: 'Recent Dose Logs',
                subtitle: 'Intake history from the past 7 days',
              ),
              StreamBuilder<List<DoseLog>>(
                stream: _medicineService.streamRecentDoseLogs(medicine.id),
                builder: (context, logSnapshot) {
                  final logs = logSnapshot.data ?? [];
                  if (logs.isEmpty) {
                    return SoftCard(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'No recent logs recorded yet.',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: logs
                        .map(
                          (log) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: SoftSurface(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    log.status == DoseStatus.taken
                                        ? Icons.check_circle_rounded
                                        : (log.status == DoseStatus.skipped ? Icons.cancel_rounded : Icons.error_outline_rounded),
                                    size: 20,
                                    color: log.status == DoseStatus.taken
                                        ? AppColors.success
                                        : (log.status == DoseStatus.skipped ? AppColors.textSecondary : AppColors.danger),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      TimeFormatter.formatDateTime12Hour(log.scheduledAt),
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    label: log.status.name.toUpperCase(),
                                    type: log.status == DoseStatus.taken
                                        ? PillType.success
                                        : (log.status == DoseStatus.skipped ? PillType.neutral : PillType.danger),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.headingSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
