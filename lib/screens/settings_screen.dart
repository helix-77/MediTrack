import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../features/bdapps/bd_apps_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../l10n/locale_notifier.dart';
import '../l10n/app_strings.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_modal_sheet.dart';
import '../widgets/soft_surface.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';

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
            Text('Log Out', style: AppTypography.headingMedium),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your MediTrack account?',
          style: AppTypography.bodySmall.copyWith(height: 1.4),
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
              await _authService.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
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

  void _showFaqModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final faqs = [
      {
        'q': 'How does prescription scanning work?',
        'a': 'MediTrack uses on-device Google ML Kit OCR and Gemini AI to recognize medicine names, dosages, and schedules directly from your camera photo.'
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
              '• Firebase AI Security:\nGemini AI calls are verified with Firebase App Check to prevent unauthorized abuse.',
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
                'BD Apps SMS Diagnostic',
                style: AppTypography.headingMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send a live adherence reminder test SMS to your linked phone number (${profile.bdMobile ?? "No number"}).',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 20),
              SoftPrimaryButton(
                label: 'Send Test Alert SMS',
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
        title: const Text('Settings'),
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
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlueLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: AppTypography.headingLarge.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.displayName, style: AppTypography.headingSmall),
                          const SizedBox(height: 2),
                          Text(
                            profile.bdMobile ?? (profile.email.isNotEmpty ? profile.email : 'Tap to edit profile details'),
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                  ],
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
                      title: Text('Pause Notifications', style: AppTypography.bodyMedium),
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
                      title: Text('Reminder & Alert Rules', style: AppTypography.bodyMedium),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
                      title: Text('Dark Mode', style: AppTypography.bodyMedium),
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
                      title: Text('Language / ভাষা', style: AppTypography.bodyMedium),
                      subtitle: Text(
                        localeNotifier.isBangla ? 'বাংলা (Bangla)' : 'English',
                        style: AppTypography.caption,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _showLanguageModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sms_outlined, color: AppColors.primaryBlue),
                      title: Text('BD Apps SMS Service', style: AppTypography.bodyMedium),
                      subtitle: Text('Carrier alert diagnostics', style: AppTypography.caption),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
                      title: Text('FAQ & Help Guide', style: AppTypography.bodyMedium),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _showFaqModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue),
                      title: Text('Terms of Service', style: AppTypography.bodyMedium),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _showTermsModal,
                    ),
                    const Divider(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue),
                      title: Text('Privacy & Security Policy', style: AppTypography.bodyMedium),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _showPrivacyModal,
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
                            'Log Out',
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
