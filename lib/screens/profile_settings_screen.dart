import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  void _showEditProfileDialog(UserProfile currentProfile) {
    final nameController = TextEditingController(text: currentProfile.displayName);
    final bloodController = TextEditingController(text: currentProfile.bloodGroup ?? '');
    final allergiesController = TextEditingController(text: currentProfile.allergies ?? '');
    final doctorNameController = TextEditingController(text: currentProfile.doctorName ?? '');
    final doctorPhoneController = TextEditingController(text: currentProfile.doctorPhone ?? '');
    final emergencyNameController = TextEditingController(text: currentProfile.emergencyContactName ?? '');
    final emergencyPhoneController = TextEditingController(text: currentProfile.emergencyContactPhone ?? '');

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
              );

              Navigator.pop(dialogContext);
              await _profileService.saveProfile(updated);
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

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // User Profile Header Card
              _buildProfileHeaderCard(profile, isGuest, user),
              const SizedBox(height: 20),

              // Medical & Emergency Info Card
              _buildMedicalInfoCard(profile),
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
