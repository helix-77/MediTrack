import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../features/bdapps/bd_apps_service.dart';
import '../features/bdapps/data/models/check_subscription_response.dart';
import '../features/bdapps/data/models/send_sms_response.dart';
import '../features/bdapps/data/models/unsubscribe_response.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'login_screen.dart';
import 'prescription_vault_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final UserProfileService _profileService = UserProfileService();
  final AuthService _authService = AuthService();
  final TextEditingController _subMobileController = TextEditingController();
  final TextEditingController _subOtpController = TextEditingController();

  @override
  void dispose() {
    _subMobileController.dispose();
    _subOtpController.dispose();
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
            content:
                Text('BD mobile must be 11 digits starting with 01[3-9]. Leaving empty.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return null;
    }
    return trimmed;
  }

  void _showEditProfileDialog(UserProfile currentProfile) {
    final nameController = TextEditingController(text: currentProfile.displayName);
    final bloodController = TextEditingController(text: currentProfile.bloodGroup ?? '');
    final allergiesController = TextEditingController(text: currentProfile.allergies ?? '');
    final doctorNameController = TextEditingController(text: currentProfile.doctorName ?? '');
    final doctorPhoneController = TextEditingController(text: currentProfile.doctorPhone ?? '');
    final emergencyNameController = TextEditingController(text: currentProfile.emergencyContactName ?? '');
    final emergencyPhoneController = TextEditingController(text: currentProfile.emergencyContactPhone ?? '');
    final bdMobileController =
        TextEditingController(text: currentProfile.bdMobile ?? '');

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
                decoration: const InputDecoration(labelText: 'Blood Group (e.g. O+)'),
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
                decoration: const InputDecoration(labelText: 'Emergency Contact Name'),
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
                  helperText: 'Used as the BD Apps subscriber ID for SMS / subscription actions',
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
              final updated = UserProfile(
                uid: currentProfile.uid,
                displayName: nameController.text.trim(),
                email: currentProfile.email,
                bloodGroup: bloodController.text.trim().isEmpty ? null : bloodController.text.trim(),
                allergies: allergiesController.text.trim().isEmpty ? null : allergiesController.text.trim(),
                doctorName: doctorNameController.text.trim().isEmpty ? null : doctorNameController.text.trim(),
                doctorPhone: doctorPhoneController.text.trim().isEmpty ? null : doctorPhoneController.text.trim(),
                emergencyContactName: emergencyNameController.text.trim().isEmpty ? null : emergencyNameController.text.trim(),
                emergencyContactPhone: emergencyPhoneController.text.trim().isEmpty ? null : emergencyPhoneController.text.trim(),
                enableDoseReminders: currentProfile.enableDoseReminders,
                enableExpiryAlerts: currentProfile.enableExpiryAlerts,
                enableLowStockAlerts: currentProfile.enableLowStockAlerts,
                bdMobile: _normalisedBdMobile(bdMobileController.text),
              );

              Navigator.pop(dialogContext);
              await _profileService.saveProfile(updated);
              // Mirror the change into the BdAppsService so the SMS /
              // Subscribe cards re-render immediately, without waiting
              // for the Firestore stream to round-trip.
              if (mounted) {
                context
                    .read<BdAppsService>()
                    .updateBdMobile(updated.bdMobile);
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
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Settings', style: AppTypography.headingLarge.copyWith(color: AppColors.primaryGreen)),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ??
              UserProfile(
                uid: user?.uid ?? '',
                displayName: isGuest ? 'Guest User' : (user.displayName ?? 'User'),
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
              _buildProfileHeaderCard(profile, isGuest, user),
              const SizedBox(height: 20),

              // Medical & Emergency Info Card
              _buildMedicalInfoCard(profile),
              const SizedBox(height: 20),

              // SMS Service — fire test SMS through BD Apps gateway
              _buildSmsServiceCard(),
              const SizedBox(height: 20),

              // Subscribe Service — manage BD Apps subscription lifecycle
              _buildSubscribeServiceCard(),
              const SizedBox(height: 20),

              // Notification & Preference Settings
              _buildNotificationSettingsCard(profile),
              const SizedBox(height: 20),

              // Account Security & Actions
              _buildAccountActionsCard(isGuest, user),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeaderCard(UserProfile profile, bool isGuest, User? user) {
    String providerText = 'Email Account';
    if (isGuest) {
      providerText = 'Guest Mode';
    } else if (user != null && user.providerData.any((p) => p.providerId.contains('google'))) {
      providerText = 'Google Account';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryGreen,
              child: Text(
                profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : 'U',
                style: AppTypography.headingLarge.copyWith(color: Colors.white, fontSize: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName, style: AppTypography.headingMedium),
                  const SizedBox(height: 4),
                  if (!isGuest && profile.email.isNotEmpty)
                    Text(profile.email, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(providerText),
                    backgroundColor: AppColors.accentPinkLight,
                    labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen),
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
                Text('Health & Emergency Profile', style: AppTypography.headingMedium),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: AppColors.primaryGreen),
                  onPressed: () => _showEditProfileDialog(profile),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(Icons.bloodtype, 'Blood Group', profile.bloodGroup ?? 'Not specified'),
            _buildInfoRow(Icons.healing, 'Allergies', profile.allergies ?? 'None listed'),
            _buildInfoRow(Icons.medical_services, 'Primary Doctor', profile.doctorName != null ? '${profile.doctorName} (${profile.doctorPhone ?? "No phone"})' : 'Not specified'),
            _buildInfoRow(Icons.contact_phone, 'Emergency Contact', profile.emergencyContactName != null ? '${profile.emergencyContactName} (${profile.emergencyContactPhone ?? "No phone"})' : 'Not specified'),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_shared_outlined, color: AppColors.primaryGreen),
              title: const Text('Digital Prescription Vault', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('View & scan stored written prescriptions'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGreen),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrescriptionVaultScreen()),
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
          Text('$label: ', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
          ),
        ],
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
            Text('App & Notification Settings', style: AppTypography.headingMedium),
            const Divider(),
            SwitchListTile(
              title: const Text('Dose Reminders'),
              subtitle: const Text('Get notified when it\'s time for scheduled medication'),
              value: profile.enableDoseReminders,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) async {
                final updated = UserProfile(
                  uid: profile.uid,
                  displayName: profile.displayName,
                  email: profile.email,
                  bloodGroup: profile.bloodGroup,
                  allergies: profile.allergies,
                  doctorName: profile.doctorName,
                  doctorPhone: profile.doctorPhone,
                  emergencyContactName: profile.emergencyContactName,
                  emergencyContactPhone: profile.emergencyContactPhone,
                  enableDoseReminders: val,
                  enableExpiryAlerts: profile.enableExpiryAlerts,
                  enableLowStockAlerts: profile.enableLowStockAlerts,
                );
                await _profileService.saveProfile(updated);
              },
            ),
            SwitchListTile(
              title: const Text('Expiry Alerts'),
              subtitle: const Text('30-day early warnings before medicine expires'),
              value: profile.enableExpiryAlerts,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) async {
                final updated = UserProfile(
                  uid: profile.uid,
                  displayName: profile.displayName,
                  email: profile.email,
                  bloodGroup: profile.bloodGroup,
                  allergies: profile.allergies,
                  doctorName: profile.doctorName,
                  doctorPhone: profile.doctorPhone,
                  emergencyContactName: profile.emergencyContactName,
                  emergencyContactPhone: profile.emergencyContactPhone,
                  enableDoseReminders: profile.enableDoseReminders,
                  enableExpiryAlerts: val,
                  enableLowStockAlerts: profile.enableLowStockAlerts,
                );
                await _profileService.saveProfile(updated);
              },
            ),
            SwitchListTile(
              title: const Text('Low Stock Alerts'),
              subtitle: const Text('Notifications when stock drops below threshold'),
              value: profile.enableLowStockAlerts,
              activeThumbColor: AppColors.primaryGreen,
              onChanged: (val) async {
                final updated = UserProfile(
                  uid: profile.uid,
                  displayName: profile.displayName,
                  email: profile.email,
                  bloodGroup: profile.bloodGroup,
                  allergies: profile.allergies,
                  doctorName: profile.doctorName,
                  doctorPhone: profile.doctorPhone,
                  emergencyContactName: profile.emergencyContactName,
                  emergencyContactPhone: profile.emergencyContactPhone,
                  enableDoseReminders: profile.enableDoseReminders,
                  enableExpiryAlerts: profile.enableExpiryAlerts,
                  enableLowStockAlerts: val,
                );
                await _profileService.saveProfile(updated);
              },
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
                    const Icon(Icons.sms_outlined,
                        color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('SMS Service',
                        style: AppTypography.headingMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? 'Send a test SMS through the BD Apps gateway to verify connectivity.'
                      : 'Link a BD mobile below to enable SMS service actions.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  enabled: enabled && !isSending,
                  leading: const Icon(Icons.send_outlined,
                      color: AppColors.primaryGreen),
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
                      : const Icon(Icons.chevron_right,
                          color: AppColors.primaryGreen),
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

  /// Subscribe service card — exposes the BD Apps subscription lifecycle
  /// (`check_subscription.php`, `unsubscribe.php`). Lets the user see
  /// their REGISTERED / UNREGISTERED state, refresh it from the server,
  /// and trigger an unsubscribe without logging out.
  Widget _buildSubscribeServiceCard() {
    return Consumer<BdAppsService>(
      builder: (context, service, _) {
        final mobile = service.bdMobile;
        final enabled = service.hasBdMobile;
        final isChecking = service.isCheckingSubscription;
        final isUnsubscribing = service.isUnsubscribing;
        final isSendingOtp = service.isSendingOtp;
        final isVerifyingOtp = service.isVerifyingOtp;
        final status = service.subscriptionStatus;
        final isRegistered = status?.toUpperCase() == 'REGISTERED';
        final hasPendingOtp = service.pendingReferenceNo != null;
        final lastResponse = service.lastCheckSubscriptionResponse;
        final lastUnsubscribe = service.lastUnsubscribeResponse;

        if (_subMobileController.text.isEmpty && mobile != null) {
          _subMobileController.text = mobile;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wifi_tethering,
                        color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Subscribe Service',
                        style: AppTypography.headingMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isRegistered
                      ? 'You are subscribed to BD Apps daily SMS service.'
                      : 'Subscribe via OTP to receive daily SMS medication updates.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Divider(),
                _buildInfoRow(
                    Icons.phone_android,
                    'BD Mobile',
                    enabled ? mobile! : 'Not linked'),
                _buildInfoRow(
                    Icons.toggle_on_outlined,
                    'Subscription State',
                    status ?? 'UNKNOWN'),
                const SizedBox(height: 12),

                if (!isRegistered) ...[
                  Text(
                    'Subscribe via OTP (Robi / Airtel)',
                    style: AppTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _subMobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'BD Mobile Number',
                      hintText: '018XXXXXXXX',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      helperText: '11-digit Robi (018) or Airtel (016) number',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSendingOtp
                          ? null
                          : () async {
                              final raw = _subMobileController.text.trim();
                              if (raw.length != 11 || !raw.startsWith('01')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid 11-digit mobile number starting with 01'),
                                    backgroundColor: AppColors.warning,
                                  ),
                                );
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              final success = await service.sendOtp(mobileNumber: raw);
                              if (!mounted) return;

                              if (success) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('OTP sent to $raw via SMS. Enter code below.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(service.errorMessage ?? 'Failed to send OTP.'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            },
                      icon: isSendingOtp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sms),
                      label: Text(isSendingOtp ? 'Sending OTP...' : 'Send OTP to Subscribe'),
                    ),
                  ),

                  if (hasPendingOtp) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Text(
                      'Enter Received OTP',
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subOtpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'OTP Code',
                        hintText: '123456',
                        prefixIcon: Icon(Icons.pin),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                        onPressed: isVerifyingOtp
                            ? null
                            : () async {
                                final code = _subOtpController.text.trim();
                                if (code.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter the OTP code received via SMS'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final bdAppsService = context.read<BdAppsService>();
                                final ok = await service.verifyOtp(otp: code);
                                if (!mounted) return;

                                if (ok) {
                                  final newMobile = _subMobileController.text.trim();
                                  await _profileService.updateBdMobile(newMobile);

                                  bdAppsService.updateBdMobile(newMobile);
                                  _subOtpController.clear();

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Successfully subscribed to BD Apps daily service!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(service.errorMessage ?? 'OTP verification failed.'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              },
                        icon: isVerifyingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(isVerifyingOtp ? 'Verifying...' : 'Verify OTP & Subscribe'),
                      ),
                    ),
                  ],
                ],

                if (enabled) ...[
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !isChecking,
                    leading: const Icon(Icons.refresh,
                        color: AppColors.primaryGreen),
                    title: const Text('Refresh Status'),
                    subtitle: const Text(
                        'Re-query check_subscription.php for current lifecycle state'),
                    trailing: isChecking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right,
                            color: AppColors.primaryGreen),
                    onTap: !isChecking
                        ? service.refreshSubscriptionStatus
                        : null,
                  ),
                  if (isRegistered)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: !isUnsubscribing,
                      leading: const Icon(Icons.unsubscribe,
                          color: AppColors.danger),
                      title: const Text('Unsubscribe from SMS Service'),
                      subtitle: Text(
                        'Send unsubscribe.php — your number will stop receiving SMS',
                        style: AppTypography.bodySmall,
                      ),
                      trailing: isUnsubscribing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right,
                              color: AppColors.danger),
                      onTap: !isUnsubscribing
                          ? () => _confirmUnsubscribe(service)
                          : null,
                    ),
                ],

                if (lastResponse != null) ...[
                  const SizedBox(height: 8),
                  _SubscriptionResponseSummary(lastResponse),
                ],
                if (lastUnsubscribe != null) ...[
                  const SizedBox(height: 4),
                  _UnsubscribeResponseSummary(lastUnsubscribe),
                ],
              ],
            ),
          ),
        );
      },
    );
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
              Text('To: $phone',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
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
        content: Text(success
            ? 'SMS dispatched via gateway.'
            : 'SMS failed: ${service.errorMessage ?? "unknown error"}'),
        backgroundColor:
            success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _confirmUnsubscribe(BdAppsService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsubscribe from SMS Service?'),
        content: const Text(
          'This sends an unsubscribe request to the BD Apps backend. '
          'You will stop receiving MediTrack SMS on this number. '
          'You can re-subscribe by linking the number again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
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

    await service.unsubscribe();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(service.subscriptionStatus == 'UNREGISTERED'
            ? 'Unsubscribed successfully.'
            : 'Unsubscribe attempt complete — see card for status.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildAccountActionsCard(bool isGuest, User? user) {
    return Card(
      child: Column(
        children: [
          if (isGuest)
            ListTile(
              leading: const Icon(Icons.login, color: AppColors.primaryGreen),
              title: const Text('Create Account / Log In'),
              subtitle: const Text('Sign in to sync your data across devices'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          else ...[
            if (user?.email != null)
              ListTile(
                leading: const Icon(Icons.lock_reset, color: AppColors.primaryGreen),
                title: const Text('Send Password Reset Email'),
                onTap: () async {
                  await _authService.sendPasswordResetEmail(user!.email!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset link sent to your email!'), backgroundColor: AppColors.success),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Log Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              onTap: () async {
                await _authService.signOut();
              },
            ),
          ],
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
        color: (ok ? AppColors.success : AppColors.danger).withValues(alpha: 0.08),
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
            Text('error: ${response.error}',
                style: AppTypography.bodySmall),
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
    final statusText =
        (status != null && status.isNotEmpty) ? status : 'NOT REGISTERED';

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
            Text('error: ${response.error}',
                style: AppTypography.bodySmall),
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
        color: (ok ? AppColors.success : AppColors.warning).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.help_outline,
                size: 18,
                color: ok ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                ok
                    ? 'Unsubscribe acknowledged'
                    : 'Unsubscribe attempt unclear — see status',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ok ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          if (response.subscriptionStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              'subscriptionStatus: ${response.subscriptionStatus}',
              style: AppTypography.bodySmall,
            ),
          ],
          if (response.statusCode != null || response.statusDetail != null) ...[
            const SizedBox(height: 2),
            Text(
              'statusCode: ${response.statusCode ?? '-'}${response.statusDetail != null ? ' · ${response.statusDetail}' : ''}',
              style: AppTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
