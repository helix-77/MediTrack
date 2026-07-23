import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../models/dose_log.dart';
import '../services/medicine_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
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
        title: const Text('Delete Medicine'),
        content: const Text('Are you sure you want to delete this medicine record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _medicineService.deleteMedicine(widget.medicineId);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicine>>(
      stream: _medicineService.streamMedicines(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            appBar: AppBar(title: const Text('Medicine Details')),
            body: const Center(child: Text('Medicine not found')),
          );
        }

        final isLowStock = RefillCalculator.isLowStock(medicine.quantityCurrent, medicine.lowStockThreshold);
        final daysLeft = RefillCalculator.daysRemaining(medicine.quantityCurrent, medicine.schedule);

        return Scaffold(
          appBar: AppBar(
            title: Text(medicine.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditMedicineScreen(medicine: medicine)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: _confirmDelete,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                color: AppColors.accentPinkLight,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medicine.name, style: AppTypography.headingLarge),
                      if (medicine.genericName != null) ...[
                        const SizedBox(height: 4),
                        Text(medicine.genericName!, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Stock Left', '${medicine.quantityCurrent} ${medicine.dosageForm ?? "units"}'),
                          _buildStatItem('Est. Supply', '$daysLeft days'),
                          _buildStatItem('Strength', medicine.strength ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Alert Cards if any
              if (isLowStock) ...[
                Card(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  child: const ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    title: Text('Low Stock Warning'),
                    subtitle: Text('Re-order or purchase refill soon.'),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Schedule Info Card
              Text('Schedule & Usage', style: AppTypography.headingSmall),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow('Dose Amount', '${medicine.schedule.doseAmount} ${medicine.dosageForm ?? "unit(s)"}'),
                      const Divider(),
                      _buildDetailRow('Dose Times', medicine.schedule.doseTimes.map(TimeFormatter.format24To12Hour).join(", ")),
                      const Divider(),
                      _buildDetailRow('Scheduled Days', TimeFormatter.formatDaysOfWeek(medicine.schedule.daysOfWeek)),
                      const Divider(),
                      _buildDetailRow('Expiry Date', medicine.expiryDate != null ? DateFormat('yyyy-MM-dd').format(medicine.expiryDate!) : 'Not set'),
                      if (medicine.batchNumber != null) ...[
                        const Divider(),
                        _buildDetailRow('Batch Number', medicine.batchNumber!),
                      ],
                      if (medicine.manufacturer != null) ...[
                        const Divider(),
                        _buildDetailRow('Manufacturer', medicine.manufacturer!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Dose History
              Text('Recent Dose Logs (Last 7 Days)', style: AppTypography.headingSmall),
              const SizedBox(height: 8),
              StreamBuilder<List<DoseLog>>(
                stream: _medicineService.streamRecentDoseLogs(medicine.id),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                          (log) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                log.status == DoseStatus.taken
                                    ? Icons.check_circle
                                    : (log.status == DoseStatus.skipped ? Icons.cancel : Icons.error),
                                color: log.status == DoseStatus.taken
                                    ? AppColors.success
                                    : (log.status == DoseStatus.skipped ? AppColors.textSecondary : AppColors.danger),
                              ),
                              title: Text(TimeFormatter.formatDateTime12Hour(log.scheduledAt)),
                              subtitle: Text('Status: ${log.status.name.toUpperCase()}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.headingSmall.copyWith(color: AppColors.primaryGreen)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
