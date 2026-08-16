import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../models/user_profile.dart';
import '../services/medicine_service.dart';
import '../services/pdf_export_service.dart';
import '../services/user_profile_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class DoctorSummaryScreen extends StatefulWidget {
  const DoctorSummaryScreen({super.key});

  @override
  State<DoctorSummaryScreen> createState() => _DoctorSummaryScreenState();
}

class _DoctorSummaryScreenState extends State<DoctorSummaryScreen> {
  final UserProfileService _profileService = UserProfileService();
  final MedicineService _medicineService = MedicineService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doctor Medication Summary'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, profileSnapshot) {
          final profile =
              profileSnapshot.data ??
              UserProfile(
                uid: '',
                displayName: 'Patient',
                email: '',
              );

          return StreamBuilder<List<Medicine>>(
            stream: _medicineService.streamMedicines(),
            builder: (context, medSnapshot) {
              final medicines = medSnapshot.data ?? [];

              return StreamBuilder<List<DoseLog>>(
                stream: _medicineService.streamTodayDoseLogs(),
                builder: (context, logSnapshot) {
                  final logs = logSnapshot.data ?? [];

                  final report = PdfExportService.generateDoctorSummaryReport(
                    profile: profile,
                    medicines: medicines,
                    recentLogs: logs,
                  );

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.medical_information,
                                  color: AppColors.primaryGreen,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Clinical Summary Ready',
                                        style: AppTypography.headingSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Share or copy your prescription and adherence report for your doctor appointment.',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                report,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy to Clipboard'),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: report),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Summary copied to clipboard!',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
