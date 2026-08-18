import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../features/bdapps/bd_apps_service.dart';
import '../features/bdapps/data/models/check_subscription_response.dart';
import '../features/bdapps/data/models/send_sms_response.dart';
import '../features/bdapps/data/models/unsubscribe_response.dart';
import '../models/user_profile.dart';
import '../models/family_member.dart';
import '../services/user_profile_service.dart';
import '../services/auth_service.dart';
import '../services/entitlement_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../services/family_service.dart';
import '../l10n/locale_notifier.dart';
import '../l10n/app_strings.dart';
import '../logic/bd_mobile_validator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/theme_notifier.dart';
import 'prescription_vault_screen.dart';
import 'nearby_pharmacies_screen.dart';
import 'doctor_summary_screen.dart';
import 'subscription_offer_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final UserProfileService _profileService = UserProfileService();
  final AuthService _authService = AuthService();
  final MedicineService _medicineService = MedicineService();
  final NotificationService _notificationService = NotificationService();
  final FamilyService _familyService = FamilyService();
  final TextEditingController _newFamilyMemberController = TextEditingController();

  @override
  void dispose() {
    _newFamilyMemberController.dispose();
    super.dispose();
  }

  /// Pattern used by the PHP backend (`backend/send_otp.php`,
  /// `backend/check_subscription.php`, etc.) for BD mobile normalisation.
  static final _bdMobileRegex = RegExp(r'^01[3-9][0-9]{8}$');

  /// Returns the digits-only 11-digit form on success or `null` if the
  /// input is empty / malformed. Used both before saving to Firestore
  /// and before mirroring into [BdAppsService] so the provider never
  /// holds an invalid number.
  String? _normalisedBdMobile(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!_bdMobileRegex.hasMatch(trimmed)) {
      // Show the user a soft warning but still accept (don't block save)
      // so they can correct later — keeps the same flow as the other
      // fields.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'BD mobile must be 11 digits starting with 01[3-9]. Leaving empty.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return null;
    }
    return trimmed;
  }

  void _showEditProfileDialog(UserProfile currentProfile) {
    final nameController = TextEditingController(
      text: currentProfile.displayName,
    );
    final bloodController = TextEditingController(
      text: currentProfile.bloodGroup ?? '',
    );
    final allergiesController = TextEditingController(
      text: currentProfile.allergies ?? '',
    );
    final doctorNameController = TextEditingController(
      text: currentProfile.doctorName ?? '',
    );
    final doctorPhoneController = TextEditingController(
      text: currentProfile.doctorPhone ?? '',
    );
    final emergencyNameController = TextEditingController(
      text: currentProfile.emergencyContactName ?? '',
    );
    final emergencyPhoneController = TextEditingController(
      text: currentProfile.emergencyContactPhone ?? '',
    );
    final bdMobileController = TextEditingController(
      text: currentProfile.bdMobile ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile & Health Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bloodController,
                decoration: const InputDecoration(
                  labelText: 'Blood Group (e.g. O+)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: allergiesController,
                decoration: const InputDecoration(labelText: 'Known Allergies'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorNameController,
                decoration: const InputDecoration(labelText: 'Doctor Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Doctor Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emergencyNameController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emergencyPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Emergency Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bdMobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'BD Mobile (for SMS service)',
                  hintText: '01XXXXXXXXX',
                  helperText:
                      'Used as the BD Apps subscriber ID for SMS / subscription actions',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = currentProfile.copyWith(
                displayName: nameController.text.trim(),
                bloodGroup: bloodController.text.trim().isEmpty
                    ? null
                    : bloodController.text.trim(),
                allergies: allergiesController.text.trim().isEmpty
                    ? null
                    : allergiesController.text.trim(),
                doctorName: doctorNameController.text.trim().isEmpty
                    ? null
                    : doctorNameController.text.trim(),
                doctorPhone: doctorPhoneController.text.trim().isEmpty
                    ? null
                    : doctorPhoneController.text.trim(),
                emergencyContactName:
                    emergencyNameController.text.trim().isEmpty
                    ? null
                    : emergencyNameController.text.trim(),
                emergencyContactPhone:
                    emergencyPhoneController.text.trim().isEmpty
                    ? null
                    : emergencyPhoneController.text.trim(),
                bdMobile: _normalisedBdMobile(bdMobileController.text),
              );

              Navigator.pop(dialogContext);
              await _profileService.saveProfile(updated);
              // Mirror the change into the BdAppsService so the SMS /
              // Subscribe cards re-render immediately, without waiting
              // for the Firestore stream to round-trip.
              if (mounted) {
                context.read<BdAppsService>().updateBdMobile(updated.bdMobile);
              }
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile & Settings',
          style: AppTypography.headingLarge.copyWith(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, snapshot) {
          final profile =
              snapshot.data ??
              UserProfile(
                uid: user?.uid ?? '',
                displayName: user?.displayName ?? 'User',
                email: user?.email ?? '',
              );

          // Keep [BdAppsService.bdMobile] in sync with the profile so the
          // SMS / Subscribe cards re-render whenever the user links /
          // unlinks a number. updateBdMobile is a no-op when the value
          // hasn't changed, but it calls notifyListeners() when it does,
          // which can't run from inside a build phase — defer to the
          // post-frame callback.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<BdAppsService>().updateBdMobile(profile.bdMobile);
          });

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // User Profile Header Card
              _buildProfileHeaderCard(profile, user),
              const SizedBox(height: 20),

              // Subscribe Service — manage BD Apps subscription lifecycle (MediTrack Premium)
              _buildSubscribeServiceCard(),
              const SizedBox(height: 20),

              // Language Selector Card
              _buildLanguageSettingsCard(),
              const SizedBox(height: 20),

              // Dark Mode Theme Card
              _buildThemeSettingsCard(),
              const SizedBox(height: 20),

              // Medical Tools & Reports Card
              _buildMedicalToolsCard(),
              const SizedBox(height: 20),

              // Family Profiles Card
              _buildFamilyProfilesCard(),
              const SizedBox(height: 20),

              // Medical & Emergency Info Card
              _buildMedicalInfoCard(profile),
              const SizedBox(height: 20),

              // SMS Service — fire test SMS through BD Apps gateway
              _buildSmsServiceCard(),
              const SizedBox(height: 20),

              // Notification & Preference Settings
              _buildNotificationSettingsCard(profile),
              const SizedBox(height: 20),

              // Account Security & Actions
              _buildAccountActionsCard(user),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeaderCard(UserProfile profile, User? user) {
    final providerText =
        user != null &&
            user.providerData.any(
              (provider) => provider.providerId.contains('google'),
            )
        ? 'Google Account'
        : 'Email Account';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryGreen,
              child: Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : 'U',
                style: AppTypography.headingLarge.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName, style: AppTypography.headingMedium),
                  const SizedBox(height: 4),
                  if (profile.email.isNotEmpty)
                    Text(
                      profile.email,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(providerText),
                    backgroundColor: AppColors.accentPinkLight,
                    labelStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primaryGreen,
              ),
              onPressed: () => _showEditProfileDialog(profile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoCard(UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Health & Emergency Profile',
                  style: AppTypography.headingMedium,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                  onPressed: () => _showEditProfileDialog(profile),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              Icons.bloodtype,
              'Blood Group',
              profile.bloodGroup ?? 'Not specified',
            ),
            _buildInfoRow(
              Icons.healing,
              'Allergies',
              profile.allergies ?? 'None listed',
            ),
            _buildInfoRow(
              Icons.medical_services,
              'Primary Doctor',
              profile.doctorName != null
                  ? '${profile.doctorName} (${profile.doctorPhone ?? "No phone"})'
                  : 'Not specified',
            ),
            _buildInfoRow(
              Icons.contact_phone,
              'Emergency Contact',
              profile.emergencyContactName != null
                  ? '${profile.emergencyContactName} (${profile.emergencyContactPhone ?? "No phone"})'
                  : 'Not specified',
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.folder_shared_outlined,
                color: AppColors.primaryGreen,
              ),
              title: const Text(
                'Digital Prescription Vault',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('View & scan stored written prescriptions'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.primaryGreen,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrescriptionVaultScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rescheduleMedicines(UserProfile profile) async {
    await for (final medicines in _medicineService.streamMedicines().take(1)) {
      for (final medicine in medicines) {
        await _notificationService.scheduleMedicineNotifications(
          medicine,
          profile: profile,
        );
      }
    }
  }

  Widget _buildLanguageSettingsCard() {
    return Consumer<LocaleNotifier>(
      builder: (context, localeNotifier, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('App Language (ভাষা)', style: AppTypography.headingMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select your preferred display language across the app.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('English')),
                        selected: !localeNotifier.isBangla,
                        selectedColor: AppColors.accentPinkLight,
                        onSelected: (selected) {
                          if (selected) localeNotifier.setLanguage(AppLanguage.english);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('বাংলা (Bangla)')),
                        selected: localeNotifier.isBangla,
                        selectedColor: AppColors.accentPinkLight,
                        onSelected: (selected) {
                          if (selected) localeNotifier.setLanguage(AppLanguage.bangla);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeSettingsCard() {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dark_mode_outlined, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Appearance & Theme', style: AppTypography.headingMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose Light, Dark, or System default theme.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Reduces eye strain at night'),
                  value: themeNotifier.isDarkMode,
                  activeThumbColor: AppColors.primaryGreen,
                  onChanged: (val) {
                    themeNotifier.toggleDarkMode(val);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicalToolsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services_outlined, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text('Medical Tools & Reports', style: AppTypography.headingMedium),
              ],
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_pharmacy_outlined, color: AppColors.primaryGreen),
              title: const Text('Nearby Pharmacies'),
              subtitle: const Text('Find 24/7 pharmacies close to your current location'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGreen),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NearbyPharmaciesScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryGreen),
              title: const Text('Export Doctor Clinical Summary'),
              subtitle: const Text('Generate printable medication & adherence report'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGreen),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyProfilesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text('Family Members', style: AppTypography.headingMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Track medicines separately for your parents, children, or dependents.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const Divider(),
            StreamBuilder<List<FamilyMember>>(
              stream: _familyService.streamFamilyMembers(),
              builder: (context, snapshot) {
                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No family members added yet. Add one below to categorize medications.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }

                return Column(
                  children: members.map((member) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentPinkLight,
                        child: Icon(Icons.person, size: 18, color: AppColors.primaryGreen),
                      ),
                      title: Text(member.displayName, style: AppTypography.bodyMedium),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                        onPressed: () async {
                          await _familyService.deleteFamilyMember(member.id);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFamilyMemberController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Amma, Baba, Child',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = _newFamilyMemberController.text.trim();
                    if (name.isNotEmpty) {
                      await _familyService.addFamilyMember(name);
                      _newFamilyMemberController.clear();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard(UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App & Notification Settings',
              style: AppTypography.headingMedium,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Dose Reminders'),
              subtitle: const Text(
                'Get notified when it\'s time for scheduled medication',
              ),
              value: profile.enableDoseReminders,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) async {
                final updated = profile.copyWith(enableDoseReminders: val);
                await _profileService.saveProfile(updated);
                await _rescheduleMedicines(updated);
              },
            ),
            SwitchListTile(
              title: const Text('Expiry Alerts'),
              subtitle: Text(
                '${profile.expiryAlertDaysBefore}-day early warnings before medicine expires',
              ),
              value: profile.enableExpiryAlerts,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) async {
                final updated = profile.copyWith(enableExpiryAlerts: val);
                await _profileService.saveProfile(updated);
                await _rescheduleMedicines(updated);
              },
            ),
            SwitchListTile(
              title: const Text('Low Stock Alerts'),
              subtitle: Text(
                'Alerts when stock drops to or below ${profile.lowStockThreshold} units',
              ),
              value: profile.enableLowStockAlerts,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) async {
                final updated = profile.copyWith(enableLowStockAlerts: val);
                await _profileService.saveProfile(updated);
                await _rescheduleMedicines(updated);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'Alert Thresholds',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Refill Warning (Days Before)'),
              subtitle: Text('${profile.refillAlertDaysBefore} days before running out'),
              trailing: DropdownButton<int>(
                value: profile.refillAlertDaysBefore,
                items: [1, 2, 3, 5, 7, 10, 14]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                    .toList(),
                onChanged: (newVal) async {
                  if (newVal == null) return;
                  final updated = profile.copyWith(refillAlertDaysBefore: newVal);
                  await _profileService.saveProfile(updated);
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expiry Warning (Days Before)'),
              subtitle: Text('${profile.expiryAlertDaysBefore} days before expiration'),
              trailing: DropdownButton<int>(
                value: profile.expiryAlertDaysBefore,
                items: [7, 14, 30, 60, 90]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                    .toList(),
                onChanged: (newVal) async {
                  if (newVal == null) return;
                  final updated = profile.copyWith(expiryAlertDaysBefore: newVal);
                  await _profileService.saveProfile(updated);
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Low Stock Threshold'),
              subtitle: Text('${profile.lowStockThreshold} units remaining'),
              trailing: DropdownButton<int>(
                value: profile.lowStockThreshold,
                items: [2, 5, 10, 15, 20]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d units')))
                    .toList(),
                onChanged: (newVal) async {
                  if (newVal == null) return;
                  final updated = profile.copyWith(lowStockThreshold: newVal);
                  await _profileService.saveProfile(updated);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// SMS service card — exposes the BD Apps SMS gateway (`sms.php` /
  /// `send_sms.php`) to the user. Lets the user fire a test SMS at their
  /// verified BD Apps number and observe the round-trip result.
  Widget _buildSmsServiceCard() {
    return Consumer<BdAppsService>(
      builder: (context, service, _) {
        final mobile = service.bdMobile;
        final enabled = service.hasBdMobile;
        final isSending = service.isSendingSms;
        final lastResponse = service.lastSendSmsResponse;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sms_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Text('SMS Service', style: AppTypography.headingMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? 'Send a test SMS through the BD Apps gateway to verify connectivity.'
                      : 'Link a BD mobile below to enable SMS service actions.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: enabled && !isSending,
                  leading: const Icon(
                    Icons.send_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Send Test SMS'),
                  subtitle: Text(
                    enabled
                        ? 'Fires a test message to $mobile via send_sms.php'
                        : 'No BD mobile linked yet',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: AppColors.primaryGreen,
                        ),
                  onTap: (!enabled || isSending)
                      ? null
                      : () => _showSendTestSmsDialog(mobile!),
                ),
                if (lastResponse != null) ...[
                  const SizedBox(height: 8),
                  _SmsResponseSummary(lastResponse),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// MediTrack Premium BD Apps subscription management card.
  Widget _buildSubscribeServiceCard() {
    return Consumer2<BdAppsService, EntitlementService>(
      builder: (context, service, entitlement, _) {
        final mobile = service.bdMobile;
        final isChecking = service.isCheckingSubscription;
        final isUnsubscribing = service.isUnsubscribing;
        final isSubscribed = entitlement.isSubscribed || service.isRegistered;
        final verifiedAt = entitlement.lastVerifiedAt;
        final formattedVerified = verifiedAt != null
            ? DateFormat('MMM d, yyyy h:mm a').format(verifiedAt)
            : 'Not checked yet';
        final lastResponse = service.lastCheckSubscriptionResponse;
        final lastUnsubscribe = service.lastUnsubscribeResponse;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MediTrack Premium',
                          style: AppTypography.headingMedium,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSubscribed
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.textSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSubscribed ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: isSubscribed ? AppColors.success : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isSubscribed
                      ? 'Active subscription via Robi / Airtel (৳2.00/day). AI Assistant, Prescription OCR, Price Lookup, and Nearby Pharmacies enabled.'
                      : 'Subscribe via Robi / Airtel (৳2.00/day) to unlock AI Prescription OCR, Gemini Assistant, Medicine Price Lookup, and Nearby Pharmacies.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const Divider(),
                _buildInfoRow(
                  Icons.phone_android,
                  'Linked BD Mobile',
                  (mobile != null && mobile.isNotEmpty)
                      ? BdMobileValidator.maskMobile(mobile)
                      : 'Not linked',
                ),
                _buildInfoRow(
                  Icons.verified_outlined,
                  'Last Verified',
                  formattedVerified,
                ),
                const SizedBox(height: 12),

                if (isSubscribed) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !isChecking,
                    leading: const Icon(
                      Icons.refresh,
                      color: AppColors.primaryGreen,
                    ),
                    title: const Text('Refresh Status'),
                    subtitle: const Text(
                      'Re-verify entitlement against BD Apps carrier servers',
                    ),
                    trailing: isChecking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.primaryGreen,
                          ),
                    onTap: !isChecking
                        ? () async {
                            await entitlement.refreshEntitlement(forceCarrierCheck: true);
                            await service.refreshSubscriptionStatus();
                          }
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !isUnsubscribing,
                    leading: const Icon(
                      Icons.unsubscribe,
                      color: AppColors.danger,
                    ),
                    title: const Text('Unsubscribe from Premium'),
                    subtitle: Text(
                      'Cancel daily carrier auto-renewal',
                      style: AppTypography.bodySmall,
                    ),
                    trailing: isUnsubscribing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.danger,
                          ),
                    onTap: !isUnsubscribing
                        ? () => _confirmUnsubscribe(service, entitlement)
                        : null,
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.stars, size: 18),
                      label: const Text('Upgrade to Premium (৳2.00/day)'),
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionOfferScreen(),
                          ),
                        );
                        if (result == true) {
                          await entitlement.refreshEntitlement(forceCarrierCheck: true);
                        }
                      },
                    ),
                  ),
                ],

                if (lastResponse != null) ...[
                  const SizedBox(height: 8),
                  _SubscriptionResponseSummary(lastResponse),
                ],
                if (lastUnsubscribe != null) ...[
                  const SizedBox(height: 8),
                  _UnsubscribeResponseSummary(lastUnsubscribe),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmUnsubscribe(
    BdAppsService service,
    EntitlementService entitlement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Premium Subscription?'),
        content: const Text(
          'This will cancel your BD Apps daily auto-renewal (৳2.78/day). '
          'You will lose access to AI Assistant, Prescription OCR, Price Lookup, and Nearby Pharmacy searches. '
          'Your saved medicines and local alerts will remain completely free.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Premium'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final success = await service.unsubscribe();
    if (!mounted) return;

    if (success) {
      entitlement.updateSubscribedState(false);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await _profileService.updateSubscriptionStatus('UNREGISTERED');
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscription canceled successfully.\nBD Apps confirmed status: ${service.subscriptionStatus ?? 'UNREGISTERED'}',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      final errorDetail = service.errorMessage ??
          service.lastUnsubscribeResponse?.statusDetail ??
          'Failed to cancel subscription via BD Apps. Please try again or dial *213# on your SIM.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorDetail),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showSendTestSmsDialog(String phone) async {
    final controller = TextEditingController(
      text: 'MediTrack test SMS — gateway round-trip OK.',
    );
    final service = context.read<BdAppsService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Test SMS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To: $phone',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 160,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final success = await service.sendSms(message: controller.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'SMS dispatched via gateway.'
              : 'SMS failed: ${service.errorMessage ?? "unknown error"}',
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Widget _buildAccountActionsCard(User? user) {
    return Card(
      child: Column(
        children: [
          if (user?.email != null)
            ListTile(
              leading: const Icon(
                Icons.lock_reset,
                color: AppColors.primaryGreen,
              ),
              title: const Text('Send Password Reset Email'),
              onTap: () async {
                await _authService.sendPasswordResetEmail(user!.email!);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset link sent to your email!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text(
              'Log Out',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
    );
  }
}

/// Tiny inline summary of the last SMS round-trip. Lives next to the SMS
/// service card so the user can see the gateway's status code / detail
/// without opening a separate sheet.
class _SmsResponseSummary extends StatelessWidget {
  const _SmsResponseSummary(this.response);

  final SendSmsResponse response;

  @override
  Widget build(BuildContext context) {
    final ok = response.isSuccess;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? AppColors.success : AppColors.danger).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: ok ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 6),
              Text(
                ok ? 'Gateway acknowledged send' : 'Gateway rejected send',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ok ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          if (response.statusCode != null || response.statusDetail != null) ...[
            const SizedBox(height: 4),
            Text(
              'statusCode: ${response.statusCode ?? '-'}${response.statusDetail != null ? ' · ${response.statusDetail}' : ''}',
              style: AppTypography.bodySmall,
            ),
          ],
          if (response.error != null) ...[
            const SizedBox(height: 2),
            Text('error: ${response.error}', style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Inline summary for a `check_subscription.php` response.
class _SubscriptionResponseSummary extends StatelessWidget {
  const _SubscriptionResponseSummary(this.response);

  final CheckSubscriptionResponse response;

  @override
  Widget build(BuildContext context) {
    final subscribed = response.isSubscribed;
    final color = subscribed ? AppColors.success : AppColors.warning;
    final status = response.subscriptionStatus;
    final statusText = (status != null && status.isNotEmpty)
        ? status
        : 'NOT REGISTERED';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                subscribed
                    ? Icons.verified_outlined
                    : Icons.report_gmailerrorred_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                subscribed
                    ? 'Server reports REGISTERED'
                    : 'Server reports $statusText',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (response.statusCode != null || response.statusDetail != null) ...[
            const SizedBox(height: 4),
            Text(
              'statusCode: ${response.statusCode ?? '-'}${response.statusDetail != null ? ' · ${response.statusDetail}' : ''}',
              style: AppTypography.bodySmall,
            ),
          ],
          if (response.statusCode == 'E1325') ...[
            const SizedBox(height: 4),
            Text(
              'Note: BD Apps requires an active Robi (018) or Airtel (016) mobile number.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (response.error != null) ...[
            const SizedBox(height: 2),
            Text('error: ${response.error}', style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Inline summary for an `unsubscribe.php` response.
class _UnsubscribeResponseSummary extends StatelessWidget {
  const _UnsubscribeResponseSummary(this.response);

  final UnsubscribeResponse response;

  @override
  Widget build(BuildContext context) {
    final ok = response.isSuccess;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? AppColors.success : AppColors.danger).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: ok ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ok
                      ? 'BD Apps Unsubscribe Confirmed'
                      : 'BD Apps Unsubscribe Failed',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ok ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          if (response.subscriptionStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              'Status: ${response.subscriptionStatus}',
              style: AppTypography.bodySmall,
            ),
          ],
          if (response.statusCode != null || response.statusDetail != null) ...[
            const SizedBox(height: 2),
            Text(
              'Details: ${response.statusCode ?? '-'}${response.statusDetail != null ? ' · ${response.statusDetail}' : ''}',
              style: AppTypography.bodySmall,
            ),
          ],
          if (!ok && response.error != null && response.error != response.statusDetail) ...[
            const SizedBox(height: 2),
            Text(
              'Error: ${response.error}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
