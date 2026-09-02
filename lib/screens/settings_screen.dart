import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/family_filter_notifier.dart';
import '../services/routine_schedule_service.dart';
import '../services/user_profile_service.dart';
import '../features/bdapps/bd_apps_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../l10n/locale_notifier.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_modal_sheet.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final UserProfileService _profileService = UserProfileService();

  bool _pauseNotifications = false;

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(context.tr('log_out'), style: AppTypography.headingMedium),
          ],
        ),
        content: Text(
          context.tr('logout_confirm_msg'),
          style: AppTypography.bodySmall.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _authService.signOut();
              if (!mounted) return;
              context.read<AvatarNotifier>().clearAvatar();
              context.read<FamilyFilterNotifier>().selectSelf();
              context.read<BdAppsService>().reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(context.tr('log_out'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettingsModal(UserProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool dose = profile.enableDoseReminders;
    bool expiry = profile.enableExpiryAlerts;
    bool stock = profile.enableLowStockAlerts;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.65,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Notification Preferences',
                style: AppTypography.headingMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage dose alarms, expiry notices and refill alerts',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Dose Intake Reminders', style: AppTypography.bodyMedium),
                subtitle: Text('Audio & visual alarms at scheduled times', style: AppTypography.caption),
                value: dose,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (val) {
                  setModalState(() => dose = val);
                  _profileService.saveProfile(profile.copyWith(enableDoseReminders: val));
                },
              ),
              const Divider(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Expiry Date Alerts', style: AppTypography.bodyMedium),
                subtitle: Text('Notifies 30 days before medication expires', style: AppTypography.caption),
                value: expiry,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (val) {
                  setModalState(() => expiry = val);
                  _profileService.saveProfile(profile.copyWith(enableExpiryAlerts: val));
                },
              ),
              const Divider(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Low Stock & Refill Alerts', style: AppTypography.bodyMedium),
                subtitle: Text('Reminds you when pill count falls below 5', style: AppTypography.caption),
                value: stock,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (val) {
                  setModalState(() => stock = val);
                  _profileService.saveProfile(profile.copyWith(enableLowStockAlerts: val));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeNotifier = context.read<LocaleNotifier>();

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.45,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Language / ভাষা নির্বাচন',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded, color: AppColors.primaryBlue),
              title: const Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: !localeNotifier.isBangla
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue)
                  : null,
              onTap: () {
                localeNotifier.setLanguage(AppLanguage.english);
                Navigator.pop(ctx);
              },
            ),
            const Divider(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.translate_rounded, color: AppColors.accentPink),
              title: const Text('বাংলা (Bangla)', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: localeNotifier.isBangla
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue)
                  : null,
              onTap: () {
                localeNotifier.setLanguage(AppLanguage.bangla);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRoutineScheduleModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schedule = context.read<RoutineScheduleNotifier>();

    var currentMorning = schedule.morningStart;
    var currentNoon = schedule.noonStart;
    var currentEvening = schedule.eveningStart;
    var currentNight = schedule.nightStart;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.88,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

          String formatTime(TimeOfDay tod) {
            final hourOfPeriod = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
            final minuteStr = tod.minute.toString().padLeft(2, '0');
            final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
            return '$hourOfPeriod:$minuteStr $period';
          }

          String formatRange(TimeOfDay start, TimeOfDay next) {
            var endMin = toMinutes(next) - 1;
            if (endMin < 0) endMin += 24 * 60;
            final endTod = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);
            return '${formatTime(start)} - ${formatTime(endTod)}';
          }

          Widget buildSlotCard({
            required String title,
            required IconData icon,
            required Color accentColor,
            required TimeOfDay start,
            required TimeOfDay next,
            required ValueChanged<TimeOfDay> onTimeChanged,
          }) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headingSmall.copyWith(
                            fontSize: 14.5,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRange(start, next),
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: start,
                      );
                      if (picked != null) {
                        setModalState(() => onTimeChanged(picked));
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatTime(start),
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkDivider : AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Routine Time Ranges',
                            style: AppTypography.headingMedium.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set start times for the 4 home screen routine grid slots',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          currentMorning = const TimeOfDay(hour: 5, minute: 0);
                          currentNoon = const TimeOfDay(hour: 11, minute: 30);
                          currentEvening = const TimeOfDay(hour: 16, minute: 0);
                          currentNight = const TimeOfDay(hour: 20, minute: 0);
                        });
                      },
                      child: Text(
                        'Reset',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                buildSlotCard(
                  title: 'Morning Routine',
                  icon: Icons.wb_sunny_rounded,
                  accentColor: const Color(0xFFF97316),
                  start: currentMorning,
                  next: currentNoon,
                  onTimeChanged: (t) => currentMorning = t,
                ),
                buildSlotCard(
                  title: 'Noon Routine',
                  icon: Icons.wb_twilight_rounded,
                  accentColor: const Color(0xFFEC4899),
                  start: currentNoon,
                  next: currentEvening,
                  onTimeChanged: (t) => currentNoon = t,
                ),
                buildSlotCard(
                  title: 'Evening Routine',
                  icon: Icons.nights_stay_outlined,
                  accentColor: const Color(0xFFA855F7),
                  start: currentEvening,
                  next: currentNight,
                  onTimeChanged: (t) => currentEvening = t,
                ),
                buildSlotCard(
                  title: 'Night Routine',
                  icon: Icons.nightlight_round,
                  accentColor: const Color(0xFF3B82F6),
                  start: currentNight,
                  next: currentMorning,
                  onTimeChanged: (t) => currentNight = t,
                ),
                const SizedBox(height: 14),
                SoftPrimaryButton(
                  label: 'Save Schedule',
                  height: 46,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await schedule.updateSchedule(
                      morning: currentMorning,
                      noon: currentNoon,
                      evening: currentEvening,
                      night: currentNight,
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('✅ Routine schedule updated successfully!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFaqModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final faqs = [
      {
        'q': 'How does prescription scanning work?',
        'a': 'MediTrack uses on-device Google ML Kit OCR and OpenRouter AI to recognize medicine names, dosages, and schedules directly from your camera photo.'
      },
      {
        'q': 'Are medication alarms active offline?',
        'a': 'Yes! Dose reminders are scheduled locally on your Android device using Flutter Local Notifications, ensuring you receive alerts even without internet.'
      },
      {
        'q': 'How do I add Bangladesh generic medicines?',
        'a': 'Use the DGDA Medicine Lookup tool in the home tab to find branded equivalents, generics, and regulated prices in Bangladesh.'
      },
      {
        'q': 'What is the BD Apps subscription?',
        'a': 'Robi and Airtel subscribers can activate automated daily SMS dose reminders to their mobile for ৳2/day via carrier billing.'
      },
    ];

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.8,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Frequently Asked Questions',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...faqs.map((faq) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.primaryBlueLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faq['q']!,
                        style: AppTypography.headingSmall.copyWith(fontSize: 13.5, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        faq['a']!,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showTermsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.75,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Terms of Service',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '1. Medical Disclaimer:\nMediTrack provides medication tracking and informational tools only. The app and its AI assistant do not offer clinical diagnosis or medical prescriptions. Always follow your registered physician\'s direct instructions.\n\n'
              '2. Data Ownership:\nYour health records, prescription archives, and dose logs belong to you and are strictly protected.\n\n'
              '3. Carrier Billing (BD Apps):\nSMS alerts via Robi/Airtel BD Apps are billed at ৳2 + VAT/SD per day upon user consent.',
              style: AppTypography.bodySmall.copyWith(
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showPrivacyModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.75,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Privacy & Security Policy',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Secure Per-User Scoping:\nAll medical logs, prescriptions, and dose schedules are scoped strictly to users/{uid} in Firebase Cloud Firestore.\n\n'
              '• On-Device ML Processing:\nText recognition on medicine boxes is performed locally on your device with Google ML Kit.\n\n'
              '• OpenRouter AI Security:\nOpenRouter AI calls are routed securely using encrypted API credentials.',
              style: AppTypography.bodySmall.copyWith(
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPasswordAccount = _authService.isPasswordAccount;
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;
    bool isDeleting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: AppTypography.headingMedium.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete your MediTrack account? This will permanently remove all your medication schedules, prescriptions, and dose history. This action cannot be undone.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (isPasswordAccount) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Confirm with your password:',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SoftTextField(
                    controller: passwordController,
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    obscureText: !isPasswordVisible,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setDialogState(() => isPasswordVisible = !isPasswordVisible);
                      },
                    ),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: AppRadii.standardRadius,
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: AppTypography.caption.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.standardRadius),
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (isPasswordAccount && passwordController.text.trim().isEmpty) {
                        setDialogState(() {
                          errorMessage = 'Please enter your password to confirm deletion.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isDeleting = true;
                        errorMessage = null;
                      });

                      try {
                        await _authService.deleteAccount(
                          password: isPasswordAccount ? passwordController.text.trim() : null,
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        if (!mounted) return;
                        final messenger = ScaffoldMessenger.of(context);
                        context.read<AvatarNotifier>().clearAvatar();
                        context.read<FamilyFilterNotifier>().selectSelf();
                        context.read<BdAppsService>().reset();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Account deleted successfully.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!dialogCtx.mounted) return;
                        final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                        setDialogState(() {
                          isDeleting = false;
                          errorMessage = cleanMsg;
                        });
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBdAppsDiagnosticModal(UserProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bdService = context.read<BdAppsService>();

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.6,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AppsPro Carrier Diagnostic',
                style: AppTypography.headingMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Verify live AppsPro / BD Apps carrier connectivity and alert status for your linked phone (${profile.bdMobile ?? "No number"}).',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 20),
              SoftPrimaryButton(
                label: 'Run Carrier Diagnostic',
                isLoading: bdService.isSendingSms,
                onPressed: () async {
                  final phone = profile.bdMobile;
                  if (phone == null || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please link a BD mobile number in Edit Profile first'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  bdService.updateBdMobile(phone);
                  final success = await bdService.sendSms(
                    message: 'MediTrack Alert: Reminder to take your scheduled Napa 500mg dose on time.',
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '✅ Test SMS sent successfully!'
                              : (bdService.errorMessage ?? 'Failed to send SMS'),
                        ),
                        backgroundColor: success ? AppColors.success : AppColors.danger,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = context.watch<ThemeNotifier>();
    final localeNotifier = context.watch<LocaleNotifier>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: Text(context.tr('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ??
              UserProfile(
                uid: '',
                displayName: 'MediTrack User',
                email: '',
              );

          final initial = profile.displayName.isNotEmpty
              ? profile.displayName[0].toUpperCase()
              : 'U';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              // Top Profile Card (Tap to Edit Profile)
              SoftSurface(
                padding: const EdgeInsets.all(16),
                borderRadius: AppRadii.cardRadius,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(profile: profile),
                    ),
                  );
                },
                child: Builder(
                  builder: (context) {
                    final avatarNotifier = context.watch<AvatarNotifier>();
                    return Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: avatarNotifier.avatarFile != null
                                ? Image.file(
                                    avatarNotifier.avatarFile!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style: AppTypography.headingLarge.copyWith(
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                style: AppTypography.headingSmall.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.bdMobile ?? (profile.email.isNotEmpty ? profile.email : 'Tap to edit profile details'),
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Notifications & Alarms
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('pause_notifications'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Switch(
                        value: _pauseNotifications,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (val) => setState(() => _pauseNotifications = val),
                      ),
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tune_rounded, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('reminder_alert_rules'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: () => _showNotificationSettingsModal(profile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Preferences & Display
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dark_mode_outlined, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('dark_mode'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Switch(
                        value: themeNotifier.isDarkMode,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (val) => themeNotifier.toggleDarkMode(val),
                      ),
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language_rounded, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('language'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        localeNotifier.isBangla ? 'বাংলা (Bangla)' : 'English',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: _showLanguageModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('routine_time_schedule'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        context.tr('routine_schedule_sub'),
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: _showRoutineScheduleModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sms_outlined, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('bdapps_sms_service'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        context.tr('carrier_alert_diagnostics'),
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: () => _showBdAppsDiagnosticModal(profile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: Help, Legal & Policies
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.help_outline_rounded, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('faq_help_guide'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: _showFaqModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('terms_of_service'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: _showTermsModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue),
                      title: Text(
                        context.tr('privacy_policy'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: _showPrivacyModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                      title: Text(
                        context.tr('delete_account'),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      onTap: _showDeleteAccountModal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Log Out Button (Matching image 2 red styled container)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C191D) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: isDark ? 0.3 : 0.2),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _confirmSignOut,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('log_out'),
                            style: AppTypography.buttonText.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          );
        },
      ),
    );
  }
}
