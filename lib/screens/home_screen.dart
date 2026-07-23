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

  Widget _buildDoseCard(_DoseItem item) {
    final isTaken = item.log.status == DoseStatus.taken;
    final isSkipped = item.log.status == DoseStatus.skipped;

    return Card(
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
          item.medicine.name,
          style: AppTypography.headingSmall.copyWith(
            decoration: isTaken ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${item.timeString} • ${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit(s)"} (${item.medicine.strength ?? ""})',
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

  Widget _buildLowStockList(List<Medicine> medicines) {
    return Column(
      children: medicines
          .map(
            (m) => Card(
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
          )
          .toList(),
    );
  }

  Widget _buildExpiringSoonList(List<Medicine> medicines) {
    return Column(
      children: medicines
          .map(
            (m) => Card(
              color: AppColors.danger.withValues(alpha: 0.1),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                title: Text(m.name, style: AppTypography.headingSmall),
                subtitle: Text('Expires: ${m.expiryDate != null ? DateFormat('yyyy-MM-dd').format(m.expiryDate!) : "N/A"}'),
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
