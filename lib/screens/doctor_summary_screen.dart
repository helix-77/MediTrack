import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../services/user_profile_service.dart';
import '../services/medicine_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';

class DoctorSummaryScreen extends StatefulWidget {
  const DoctorSummaryScreen({super.key});

  @override
  State<DoctorSummaryScreen> createState() => _DoctorSummaryScreenState();
}

class _DoctorSummaryScreenState extends State<DoctorSummaryScreen> {
  final UserProfileService _profileService = UserProfileService();
  final MedicineService _medicineService = MedicineService();

  void _copyToClipboard(String summary) {
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Doctor summary copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Doctor Visit Summary'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data ??
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

                  final summaryText = PdfExportService.generateDoctorSummaryReport(
                    profile: profile,
                    medicines: medicines,
                    recentLogs: logs,
                  );

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Clinical Header Card
                      SoftSurface(
                        padding: const EdgeInsets.all(20),
                        borderRadius: AppRadii.cardRadius,
                        color: isDark ? AppColors.darkSurface : AppColors.surface,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlueLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medical_information_rounded,
                                color: AppColors.primaryBlue,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clinical Summary Ready',
                                    style: AppTypography.headingSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Includes active prescriptions, dosages, adherence rate, and health profile.',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Report Preview Card
                      const SectionHeader(
                        title: 'Generated Clinical Report',
                        subtitle: 'Share or print for physician consultation',
                      ),
                      SoftSurface(
                        padding: const EdgeInsets.all(16),
                        color: isDark ? const Color(0xFF161E2C) : const Color(0xFFF8FAFC),
                        child: SelectableText(
                          summaryText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            height: 1.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Copy Action Button
                      SoftPrimaryButton(
                        label: 'Copy Report to Clipboard',
                        icon: Icons.copy_rounded,
                        onPressed: () => _copyToClipboard(summaryText),
                      ),
                      const SizedBox(height: 32),
                    ],
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
