import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../services/medicine_service.dart';
import '../services/auth_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import 'add_edit_medicine_screen.dart';
import 'medicine_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MedicineService _medicineService = MedicineService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkMissedDoses();
  }

  void _checkMissedDoses() async {
    try {
      await _medicineService.checkAndMarkMissedDoses();
    } catch (_) {
      // Ignored if user not authenticated yet
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;
    final displayName = isGuest ? 'Guest User' : (user.displayName ?? user.email ?? 'User');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MediTrack', style: AppTypography.headingLarge.copyWith(color: AppColors.primaryGreen)),
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, size: 28, color: AppColors.primaryGreen),
            onSelected: (value) async {
              if (value == 'logout') {
                await _authService.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: AppTypography.headingSmall),
                    if (!isGuest && user.email != null)
                      Text(user.email!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const Divider(),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      isGuest ? Icons.login : Icons.logout,
                      color: isGuest ? AppColors.primaryGreen : AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGuest ? 'Log In / Sign Up' : 'Log Out',
                      style: TextStyle(
                        color: isGuest ? AppColors.primaryGreen : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditMedicineScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: _medicineService.streamMedicines(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error loading data: ${snapshot.error}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final medicines = snapshot.data ?? [];

          if (medicines.isEmpty) {
            return _buildEmptyState(context);
          }

          final lowStockMedicines = medicines.where((m) => RefillCalculator.isLowStock(m.quantityCurrent, m.lowStockThreshold)).toList();
          final expiringMedicines = medicines.where((m) => RefillCalculator.isExpiringSoon(m.expiryDate)).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Today's Doses Section
              Text("Today's Doses", style: AppTypography.headingMedium),
              const SizedBox(height: 8),
              _buildTodayDosesSection(medicines),
              const SizedBox(height: 24),

              // Low Stock Alert Section
              if (lowStockMedicines.isNotEmpty) ...[
                Text('Low Stock Alerts', style: AppTypography.headingMedium),
                const SizedBox(height: 8),
                _buildLowStockList(lowStockMedicines),
                const SizedBox(height: 24),
              ],

              // Expiring Soon Section
              if (expiringMedicines.isNotEmpty) ...[
                Text('Expiring Soon', style: AppTypography.headingMedium),
                const SizedBox(height: 8),
                _buildExpiringSoonList(expiringMedicines),
                const SizedBox(height: 24),
              ],

              // All Prescriptions Section
              Text('My Prescriptions (${medicines.length})', style: AppTypography.headingMedium),
              const SizedBox(height: 8),
              _buildAllPrescriptionsSection(medicines),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.accentPinkLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medication_outlined, size: 64, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 24),
            Text('No medicines added yet', style: AppTypography.headingMedium),
            const SizedBox(height: 8),
            Text(
              'Add your daily prescriptions, dosages, and expiry dates to get timely reminders.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditMedicineScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add your first medicine'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayDosesSection(List<Medicine> medicines) {
    return StreamBuilder<List<DoseLog>>(
      stream: _medicineService.streamTodayDoseLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        
        // Combine active medicines with dose times to show today's schedule
        final List<_DoseItem> doseItems = [];
        for (var med in medicines) {
          if (!med.schedule.active) continue;
          for (var time in med.schedule.doseTimes) {
            final matchingLog = logs.firstWhere(
              (l) => l.medicineId == med.id && DateFormat('HH:mm').format(l.scheduledAt) == time,
              orElse: () => DoseLog(
                id: '',
                medicineId: med.id,
                medicineName: med.name,
                scheduledAt: _parseTodayTime(time),
                status: DoseStatus.pending,
              ),
            );
            doseItems.add(_DoseItem(medicine: med, log: matchingLog, timeString: time));
          }
        }

        doseItems.sort((a, b) => a.timeString.compareTo(b.timeString));

        if (doseItems.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No doses scheduled for today.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          children: doseItems.map((item) => _buildDoseCard(item)).toList(),
        );
      },
    );
  }

  DateTime _parseTodayTime(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts[0]) ?? 8,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  Widget _wrapWithDismissible({
    required Key key,
    required String medicineId,
    required String medicineName,
    required Widget child,
  }) {
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Medicine Prescription'),
            content: Text('Are you sure you want to delete "$medicineName"? This will delete the entire prescription and all its scheduled doses.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) async {
        await _medicineService.deleteMedicine(medicineId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$medicineName" deleted'),
            backgroundColor: AppColors.danger,
          ),
        );
      },
      child: child,
    );
  }

  Widget _wrapWithDoseDismissible({
    required _DoseItem item,
    required Widget child,
  }) {
    return Dismissible(
      key: Key('dose_${item.medicine.id}_${item.timeString}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Options',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(width: 8),
            Icon(Icons.tune, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${item.medicine.name} (${TimeFormatter.format24To12Hour(item.timeString)} Dose)'),
            content: const Text('Select an option for this dose entry:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                onPressed: () async {
                  Navigator.pop(dialogContext, false);
                  await _medicineService.updateDoseStatus(
                    logId: item.log.id,
                    medicineId: item.medicine.id,
                    medicineName: item.medicine.name,
                    status: DoseStatus.skipped,
                    doseAmount: item.medicine.schedule.doseAmount,
                    scheduledAt: item.log.scheduledAt,
                  );
                },
                child: const Text('Skip Today\'s Dose'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Delete Prescription'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) async {
        await _medicineService.deleteMedicine(item.medicine.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription "${item.medicine.name}" deleted'),
            backgroundColor: AppColors.danger,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildDoseCard(_DoseItem item) {
    final isTaken = item.log.status == DoseStatus.taken;
    final isSkipped = item.log.status == DoseStatus.skipped;
    final formattedTime = TimeFormatter.format24To12Hour(item.timeString);
    final daysText = TimeFormatter.formatDaysOfWeek(item.medicine.schedule.daysOfWeek);

    return _wrapWithDoseDismissible(
      item: item,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isTaken
                  ? AppColors.success.withValues(alpha: 0.15)
                  : (isSkipped ? AppColors.textSecondary.withValues(alpha: 0.15) : AppColors.accentPinkLight),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTaken
                  ? Icons.check
                  : (isSkipped ? Icons.close : Icons.medication),
              color: isTaken
                  ? AppColors.success
                  : (isSkipped ? AppColors.textSecondary : AppColors.primaryGreen),
            ),
          ),
          title: Text(
            '${item.medicine.name} ($formattedTime Dose)',
            style: AppTypography.headingSmall.copyWith(
              decoration: isTaken ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            '${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit(s)"} • $daysText',
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
      ),
    );
  }

  Widget _buildLowStockList(List<Medicine> medicines) {
    return Column(
      children: medicines
          .map(
            (m) => _wrapWithDismissible(
              key: Key('low_${m.id}'),
              medicineId: m.id,
              medicineName: m.name,
              child: Card(
                color: AppColors.warning.withValues(alpha: 0.1),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  title: Text(m.name, style: AppTypography.headingSmall),
                  subtitle: Text('Current Stock: ${m.quantityCurrent} (Threshold: ${m.lowStockThreshold})'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditMedicineScreen(medicine: m),
                        ),
                      );
                    },
                    child: const Text('Refill'),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildExpiringSoonList(List<Medicine> medicines) {
    return Column(
      children: medicines
          .map(
            (m) => _wrapWithDismissible(
              key: Key('exp_${m.id}'),
              medicineId: m.id,
              medicineName: m.name,
              child: Card(
                color: AppColors.danger.withValues(alpha: 0.1),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                  title: Text(m.name, style: AppTypography.headingSmall),
                  subtitle: Text('Expires: ${m.expiryDate != null ? DateFormat('yyyy-MM-dd').format(m.expiryDate!) : "N/A"}'),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAllPrescriptionsSection(List<Medicine> medicines) {
    return Column(
      children: medicines
          .map(
            (m) => _wrapWithDismissible(
              key: Key('all_${m.id}'),
              medicineId: m.id,
              medicineName: m.name,
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.medication_liquid_outlined, color: AppColors.primaryGreen),
                  title: Text(m.name, style: AppTypography.headingSmall),
                  subtitle: Text(
                    '${m.schedule.doseTimes.length} dose(s)/day (${m.schedule.doseTimes.map(TimeFormatter.format24To12Hour).join(', ')}) • ${TimeFormatter.formatDaysOfWeek(m.schedule.daysOfWeek)}',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: Text(
                    '${m.quantityCurrent} left',
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicineDetailScreen(medicineId: m.id),
                      ),
                    );
                  },
                ),
              ),
            ),
          )
          .toList(),
    );
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
