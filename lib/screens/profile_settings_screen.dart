import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/family_member.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/family_service.dart';
import '../services/entitlement_service.dart';
import '../features/bdapps/bd_apps_service.dart';
import '../theme/theme_notifier.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../l10n/locale_notifier.dart';
import '../l10n/app_strings.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import 'doctor_summary_screen.dart';
import 'prescription_vault_screen.dart';
import 'medicine_search_screen.dart';
import 'nearby_pharmacies_screen.dart';
import 'subscription_offer_screen.dart';
import 'welcome_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final AuthService _authService = AuthService();
  final UserProfileService _profileService = UserProfileService();
  final FamilyService _familyService = FamilyService();

  bool _doseReminders = true;
  bool _expiryAlerts = true;
  bool _refillAlerts = true;

  void _showEditProfileDialog(UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.displayName);
    final phoneCtrl = TextEditingController(text: profile.bdMobile ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Edit Profile', style: AppTypography.headingMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftTextField(
              controller: nameCtrl,
              labelText: 'Display Name',
              hintText: 'e.g. John Doe',
            ),
            const SizedBox(height: 12),
            SoftTextField(
              controller: phoneCtrl,
              labelText: 'Phone Number (BD Mobile)',
              hintText: '018XXXXXXXX',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () async {
              final updated = profile.copyWith(
                displayName: nameCtrl.text.trim(),
                bdMobile: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              await _profileService.saveProfile(updated);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditHealthProfileDialog(UserProfile profile) {
    final bloodCtrl = TextEditingController(text: profile.bloodGroup ?? '');
    final allergiesCtrl = TextEditingController(text: profile.allergies ?? '');
    final emNameCtrl = TextEditingController(text: profile.emergencyContactName ?? '');
    final emPhoneCtrl = TextEditingController(text: profile.emergencyContactPhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Emergency Health Profile', style: AppTypography.headingMedium),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftTextField(
                controller: bloodCtrl,
                labelText: 'Blood Group',
                hintText: 'e.g. O+, A+, B-',
              ),
              const SizedBox(height: 12),
              SoftTextField(
                controller: allergiesCtrl,
                labelText: 'Allergies',
                hintText: 'e.g. Penicillin, Peanuts',
              ),
              const SizedBox(height: 12),
              SoftTextField(
                controller: emNameCtrl,
                labelText: 'Emergency Contact Name',
                hintText: 'e.g. Jane Doe (Spouse)',
              ),
              const SizedBox(height: 12),
              SoftTextField(
                controller: emPhoneCtrl,
                labelText: 'Emergency Contact Phone',
                hintText: '017XXXXXXXX',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () async {
              final updated = profile.copyWith(
                bloodGroup: bloodCtrl.text.trim().isEmpty ? null : bloodCtrl.text.trim(),
                allergies: allergiesCtrl.text.trim().isEmpty ? null : allergiesCtrl.text.trim(),
                emergencyContactName: emNameCtrl.text.trim().isEmpty ? null : emNameCtrl.text.trim(),
                emergencyContactPhone: emPhoneCtrl.text.trim().isEmpty ? null : emPhoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              await _profileService.saveProfile(updated);
            },
            child: const Text('Save Profile', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddFamilyMemberDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Add Family Member', style: AppTypography.headingMedium),
        content: SoftTextField(
          controller: nameCtrl,
          labelText: 'Full Name',
          hintText: 'e.g. Fatima Begum (Mother)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(ctx);
              await _familyService.addFamilyMember(name);
            },
            child: const Text('Add Member', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Sign Out', style: AppTypography.headingMedium),
        content: Text(
          'Are you sure you want to sign out of MediTrack?',
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
              await _authService.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = context.watch<ThemeNotifier>();
    final localeNotifier = context.watch<LocaleNotifier>();
    final entitlement = context.watch<EntitlementService>();
    final bdService = context.watch<BdAppsService>();
    final isPro = entitlement.isSubscribed;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data ??
              UserProfile(
                uid: '',
                displayName: 'MediTrack User',
                email: '',
              );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              // User Profile Header Card
              SoftSurface(
                padding: const EdgeInsets.all(18),
                borderRadius: AppRadii.cardRadius,
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlueLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : 'U',
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
                          Text(profile.displayName, style: AppTypography.headingMedium),
                          const SizedBox(height: 2),
                          Text(
                            profile.bdMobile ?? 'No mobile linked',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    SoftIconButton(
                      icon: Icons.edit_outlined,
                      size: 38,
                      iconColor: AppColors.primaryBlue,
                      onPressed: () => _showEditProfileDialog(profile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // MediTrack Premium Status Card
              SoftSurface(
                padding: const EdgeInsets.all(18),
                borderRadius: AppRadii.cardRadius,
                color: isPro
                    ? (isDark ? const Color(0xFF152A1E) : AppColors.successLight)
                    : (isDark ? AppColors.darkSurface : AppColors.surface),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPro ? AppColors.success.withValues(alpha: 0.2) : AppColors.primaryBlueLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPro ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                        color: isPro ? AppColors.success : AppColors.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPro ? 'MediTrack Premium Active' : 'MediTrack Free Tier',
                            style: AppTypography.headingSmall.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPro
                                ? 'Full access to AI, OCR & Family SMS alerts'
                                : 'Upgrade for ৳2/day via Robi/Airtel',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    SoftPrimaryButton(
                      label: isPro ? 'Active' : 'Upgrade',
                      height: 34,
                      width: 86,
                      backgroundColor: isPro ? AppColors.success : AppColors.primaryBlue,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionOfferScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // App Preferences (Language & Dark Mode)
              const SectionHeader(title: 'App Preferences'),
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language_rounded, color: AppColors.primaryBlue),
                      title: Text('Language / ভাষা', style: AppTypography.bodyMedium),
                      subtitle: Text(
                        localeNotifier.isBangla ? 'বাংলা (Bangla)' : 'English',
                        style: AppTypography.caption,
                      ),
                      trailing: Switch(
                        value: localeNotifier.isBangla,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          localeNotifier.setLanguage(val ? AppLanguage.bangla : AppLanguage.english);
                        },
                      ),
                    ),
                    const Divider(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dark_mode_outlined, color: AppColors.primaryBlue),
                      title: Text('Dark Mode', style: AppTypography.bodyMedium),
                      subtitle: Text(
                        themeNotifier.isDarkMode ? 'Enabled' : 'Disabled (Light theme)',
                        style: AppTypography.caption,
                      ),
                      trailing: Switch(
                        value: themeNotifier.isDarkMode,
                        activeThumbColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          themeNotifier.toggleDarkMode(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Medical Tools & Reports Shortcuts
              const SectionHeader(title: 'Medical Tools & Clinical Vault'),
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryBlue),
                      title: Text('Generate Doctor Visit Summary', style: AppTypography.bodyMedium),
                      subtitle: Text('Adherence, active doses & health summary', style: AppTypography.caption),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
                        );
                      },
                    ),
                    const Divider(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_shared_outlined, color: AppColors.primaryBlue),
                      title: Text('Prescription Digital Vault', style: AppTypography.bodyMedium),
                      subtitle: Text('Scanned doctor prescriptions & archives', style: AppTypography.caption),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrescriptionVaultScreen()),
                        );
                      },
                    ),
                    const Divider(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                      title: Text('Medicine Price & Generic Lookup', style: AppTypography.bodyMedium),
                      subtitle: Text('DGDA Bangladesh database & cheaper alternatives', style: AppTypography.caption),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MedicineSearchScreen()),
                        );
                      },
                    ),
                    const Divider(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_pharmacy_outlined, color: AppColors.primaryBlue),
                      title: Text('Find Nearby Pharmacies', style: AppTypography.bodyMedium),
                      subtitle: Text('24/7 pharmacies, GPS routing & model shops', style: AppTypography.caption),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NearbyPharmaciesScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Family Profiles Manager
              SectionHeader(
                title: 'Family Profiles',
                subtitle: 'Manage prescriptions and SMS alerts for family members',
                trailing: TextButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primaryBlue),
                  label: Text('Add Member', style: AppTypography.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
                  onPressed: _showAddFamilyMemberDialog,
                ),
              ),
              StreamBuilder<List<FamilyMember>>(
                stream: _familyService.streamFamilyMembers(),
                builder: (context, fSnapshot) {
                  final members = fSnapshot.data ?? [];
                  if (members.isEmpty) {
                    return SoftCard(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No family members added yet. Tap "Add Member" to manage medications for your parents or children.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: members
                        .map(
                          (m) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: SoftSurface(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.family_restroom_rounded, color: AppColors.primaryBlue, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(m.displayName, style: AppTypography.headingSmall.copyWith(fontSize: 14)),
                                  ),
                                  SoftIconButton(
                                    icon: Icons.delete_outline,
                                    size: 32,
                                    iconSize: 16,
                                    iconColor: AppColors.danger,
                                    onPressed: () => _familyService.deleteFamilyMember(m.id),
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

              // Health & Emergency Profile Summary
              SectionHeader(
                title: 'Health & Emergency Profile',
                subtitle: 'Important data for clinical emergencies',
                trailing: TextButton(
                  onPressed: () => _showEditHealthProfileDialog(profile),
                  child: Text('Edit', style: AppTypography.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
                ),
              ),
              SoftSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHealthRow('Blood Group', profile.bloodGroup ?? 'Not set'),
                    const Divider(height: 16),
                    _buildHealthRow('Allergies', profile.allergies ?? 'None reported'),
                    const Divider(height: 16),
                    _buildHealthRow('Emergency Contact', '${profile.emergencyContactName ?? "Not set"} (${profile.emergencyContactPhone ?? "N/A"})'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notification Reminders Settings
              const SectionHeader(title: 'Notification Reminders'),
              SoftSurface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Dose Intake Reminders', style: AppTypography.bodyMedium),
                      subtitle: Text('Alarms when it is time to take your dose', style: AppTypography.caption),
                      value: _doseReminders,
                      activeThumbColor: AppColors.primaryBlue,
                      onChanged: (val) => setState(() => _doseReminders = val),
                    ),
                    const Divider(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Expiry Date Alerts', style: AppTypography.bodyMedium),
                      subtitle: Text('Warns 30 days before medication expires', style: AppTypography.caption),
                      value: _expiryAlerts,
                      activeThumbColor: AppColors.primaryBlue,
                      onChanged: (val) => setState(() => _expiryAlerts = val),
                    ),
                    const Divider(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Low Stock Alerts', style: AppTypography.bodyMedium),
                      subtitle: Text('Reminds to buy refills when inventory drops', style: AppTypography.caption),
                      value: _refillAlerts,
                      activeThumbColor: AppColors.primaryBlue,
                      onChanged: (val) => setState(() => _refillAlerts = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // BD Apps SMS Service Test (Diagnostic)
              const SectionHeader(
                title: 'BD Apps SMS Service',
                subtitle: 'Diagnostic test for Bangladesh SMS alerts',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test SMS Dispatch', style: AppTypography.headingSmall.copyWith(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Sends an adherence test SMS to your number', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    SoftPrimaryButton(
                      label: 'Send Test',
                      height: 36,
                      width: 96,
                      isLoading: bdService.isSendingSms,
                      onPressed: bdService.isSendingSms
                          ? null
                          : () async {
                              final phone = profile.bdMobile;
                              if (phone == null || phone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please link a BD mobile number in your profile first'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }
                              bdService.updateBdMobile(phone);
                              final success = await bdService.sendSms(
                                message: 'MediTrack Alert: Reminder to take your scheduled Napa 500mg dose on time.',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? '✅ Test SMS queued successfully!'
                                          : (bdService.errorMessage ?? 'Failed to send SMS'),
                                    ),
                                    backgroundColor: success ? AppColors.success : AppColors.danger,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account Actions & Sign Out
              SoftSecondaryButton(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                textColor: AppColors.danger,
                onPressed: _confirmSignOut,
              ),
              const SizedBox(height: 36),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHealthRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption),
        Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
