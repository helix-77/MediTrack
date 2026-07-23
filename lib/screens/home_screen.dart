import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../models/user_profile.dart';
import '../services/medicine_service.dart';
import '../services/user_profile_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import 'add_edit_medicine_screen.dart';
import 'medicine_detail_screen.dart';
import 'main_navigation_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MedicineService _medicineService = MedicineService();
  final UserProfileService _profileService = UserProfileService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: _profileService.streamProfile(),
          builder: (context, profileSnapshot) {
            final user = FirebaseAuth.instance.currentUser;
            final profile = profileSnapshot.data;
            final displayName = profile?.displayName ?? user?.displayName ?? (user?.isAnonymous ?? true ? 'Guest' : 'User');

            return StreamBuilder<List<Medicine>>(
              stream: _medicineService.streamMedicines(),
              builder: (context, medSnapshot) {
                final allMedicines = medSnapshot.data ?? [];
                final filteredMedicines = _searchQuery.isEmpty
                    ? allMedicines
                    : allMedicines.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                final lowStockMedicines = allMedicines.where((m) => RefillCalculator.isLowStock(m.quantityCurrent, m.lowStockThreshold)).toList();
                final expiringMedicines = allMedicines.where((m) => RefillCalculator.isExpiringSoon(m.expiryDate)).toList();

                return StreamBuilder<List<DoseLog>>(
                  stream: _medicineService.streamTodayDoseLogs(),
                  builder: (context, logSnapshot) {
                    final todayLogs = logSnapshot.data ?? [];
                    final doseItems = _generateTodayDoseItems(filteredMedicines, todayLogs);

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        // Top Header Bar (Grid Icon, Title "Home", Notification Bell)
                        _buildTopHeaderBar(),
                        const SizedBox(height: 16),

                        // Greeting Text
                        Text(
                          'Hi $displayName!',
                          style: AppTypography.headingLarge.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getGreetingSubtitle(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        _buildSearchBar(),
                        const SizedBox(height: 20),

                        // Welcome Hero Card Banner
                        _buildWelcomeHeroBanner(),
                        const SizedBox(height: 24),

                        // Ongoing Routine Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ongoing Routine',
                              style: AppTypography.headingMedium.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                MainNavigationShell.of(context)?.switchTab(1);
                              },
                              child: Text(
                                'view all',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2-Column Grid for Dose Cards
                        if (doseItems.isEmpty)
                          _buildEmptyDoseGridCard()
                        else
                          _buildDoseGrid(doseItems),

                        const SizedBox(height: 28),

                        // Low Stock Alert Section
                        if (lowStockMedicines.isNotEmpty) ...[
                          Text('Low Stock Alerts', style: AppTypography.headingMedium),
                          const SizedBox(height: 12),
                          _buildLowStockList(lowStockMedicines),
                          const SizedBox(height: 24),
                        ],

                        // Expiring Soon Section
                        if (expiringMedicines.isNotEmpty) ...[
                          Text('Expiring Soon', style: AppTypography.headingMedium),
                          const SizedBox(height: 12),
                          _buildExpiringSoonList(expiringMedicines),
                          const SizedBox(height: 24),
                        ],

                        // All Prescriptions Section
                        Text('My Prescriptions (${allMedicines.length})', style: AppTypography.headingMedium),
                        const SizedBox(height: 12),
                        _buildAllPrescriptionsSection(allMedicines),
                        const SizedBox(height: 32),
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

  Widget _buildTopHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left App Grid Icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: AppColors.primaryGreen,
            size: 22,
          ),
        ),
        // Center Title "Home"
        Text(
          'Home',
          style: AppTypography.headingSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        // Right Notification Bell with Dot Badge
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primaryGreen,
                size: 22,
              ),
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search medicines or prescriptions...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome!',
                  style: AppTypography.headingMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Let\'s schedule your routine & medicine intake',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentPinkLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: AppColors.primaryGreen,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDoseGridCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 44, color: AppColors.primaryGreen),
            const SizedBox(height: 12),
            Text('No Doses Scheduled Today', style: AppTypography.headingSmall),
            const SizedBox(height: 6),
            Text(
              'Tap the + button below to add a medicine to your daily routine.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoseGrid(List<_DoseItem> doseItems) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: doseItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.92,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final item = doseItems[index];
        final isFeatured = index == 0; // First card gets dark accent styling like reference layout!
        return _buildGridDoseCard(item, isFeatured);
      },
    );
  }

  Widget _buildGridDoseCard(_DoseItem item, bool isFeatured) {
    final isTaken = item.log.status == DoseStatus.taken;
    final isSkipped = item.log.status == DoseStatus.skipped;
    final formattedTime = TimeFormatter.format24To12Hour(item.timeString);
    final dateStr = DateFormat('MMM d, yyyy').format(item.log.scheduledAt);

    final cardBgColor = isFeatured ? AppColors.primaryGreen : AppColors.surface;
    final primaryTextColor = isFeatured ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isFeatured ? Colors.white70 : AppColors.textSecondary;
    final iconBgColor = isFeatured ? Colors.white.withValues(alpha: 0.2) : AppColors.accentPinkLight;
    final iconColor = isFeatured ? Colors.white : AppColors.primaryGreen;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFeatured ? 0.1 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Date & 3-Dots Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, color: secondaryTextColor, size: 18),
                  onSelected: (val) async {
                    if (val == 'take') {
                      await _medicineService.updateDoseStatus(
                        logId: item.log.id,
                        medicineId: item.medicine.id,
                        medicineName: item.medicine.name,
                        status: DoseStatus.taken,
                        doseAmount: item.medicine.schedule.doseAmount,
                        scheduledAt: item.log.scheduledAt,
                      );
                    } else if (val == 'skip') {
                      await _medicineService.updateDoseStatus(
                        logId: item.log.id,
                        medicineId: item.medicine.id,
                        medicineName: item.medicine.name,
                        status: DoseStatus.skipped,
                        doseAmount: item.medicine.schedule.doseAmount,
                        scheduledAt: item.log.scheduledAt,
                      );
                    } else if (val == 'delete') {
                      _showDeleteConfirmationDialog(item.medicine);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isTaken)
                      const PopupMenuItem(value: 'take', child: Text('Mark as Taken')),
                    if (!isSkipped)
                      const PopupMenuItem(value: 'skip', child: Text('Skip Dose')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Prescription', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              ],
            ),

            // Middle Section: Icon, Medicine Name & Subtitle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTaken ? Icons.check : (isSkipped ? Icons.close : Icons.medication),
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headingSmall.copyWith(
                          color: primaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          decoration: isTaken ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$formattedTime • ${item.medicine.schedule.doseAmount} ${item.medicine.dosageForm ?? "unit"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Section: Progress Bar / Badge Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: AppTypography.bodySmall.copyWith(
                        color: secondaryTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isTaken ? '100%' : (isSkipped ? 'Skipped' : '0%'),
                      style: AppTypography.bodySmall.copyWith(
                        color: primaryTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: isTaken ? 1.0 : (isSkipped ? 0.0 : 0.2),
                    minHeight: 6,
                    backgroundColor: isFeatured ? Colors.white24 : AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFeatured ? AppColors.accentPink : AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
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
        title: const Text('Delete Medicine Prescription'),
        content: Text('Are you sure you want to delete "${medicine.name}"? This will delete the entire prescription and all its scheduled doses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _medicineService.deleteMedicine(medicine.id);
            },
            child: const Text('Delete'),
          ),
        ],
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

  Widget _buildAllPrescriptionsSection(List<Medicine> medicines) {
    return Column(
      children: medicines
          .map(
            (m) => Card(
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
          )
          .toList(),
    );
  }

  List<_DoseItem> _generateTodayDoseItems(List<Medicine> medicines, List<DoseLog> todayLogs) {
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
        final scheduledDateTime = DateTime(today.year, today.month, today.day, hour, minute);

        final matchingLog = todayLogs.firstWhere(
          (l) => l.medicineId == med.id && _isSameDay(l.scheduledAt, today) && DateFormat('HH:mm').format(l.scheduledAt) == time,
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
