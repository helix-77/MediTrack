import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserProfileService _profileService = UserProfileService();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _bloodGroupController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;

  File? _avatarImage;
  bool _isSaving = false;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _phoneController = TextEditingController(text: widget.profile.bdMobile ?? '');
    _emailController = TextEditingController(text: widget.profile.email);
    _bloodGroupController = TextEditingController(text: widget.profile.bloodGroup ?? '');
    _allergiesController = TextEditingController(text: widget.profile.allergies ?? '');
    _emergencyNameController = TextEditingController(text: widget.profile.emergencyContactName ?? '');
    _emergencyPhoneController = TextEditingController(text: widget.profile.emergencyContactPhone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatarImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = widget.profile.copyWith(
        displayName: name,
        bdMobile: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        bloodGroup: _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
        allergies: _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim().isEmpty ? null : _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim().isEmpty ? null : _emergencyPhoneController.text.trim(),
      );

      await _profileService.saveProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('Delete Account', style: AppTypography.headingMedium),
          ],
        ),
        content: Text(
          'Are you sure you want to request account deletion? All your prescription archives and dose records will be permanently removed.',
          style: AppTypography.bodySmall.copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request submitted.'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = widget.profile.displayName.isNotEmpty
        ? widget.profile.displayName[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Avatar with camera badge
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0EDFE),
                        boxShadow: AppShadows.floating,
                      ),
                      child: ClipOval(
                        child: _avatarImage != null
                            ? Image.file(_avatarImage!, width: 96, height: 96, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  initial,
                                  style: AppTypography.displayLarge.copyWith(
                                    color: AppColors.primaryBlue,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: AppShadows.subtle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Tap to change photo',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Personal Information Card
            Text(
              'Personal Information',
              style: AppTypography.headingSmall.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SoftSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SoftTextField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    hintText: 'e.g. Dr. John Doe',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(height: 14),
                  SoftTextField(
                    controller: _phoneController,
                    labelText: 'Phone Number (BD Mobile)',
                    hintText: '018XXXXXXXX',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(height: 14),
                  SoftTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    hintText: 'user@example.com',
                    enabled: false,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryBlue, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Emergency & Clinical Profile Card
            Text(
              'Emergency & Clinical Details',
              style: AppTypography.headingSmall.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SoftSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood Group Selector
                  Text('Blood Group', style: AppTypography.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bloodGroups.map((bg) {
                      final isSelected = _bloodGroupController.text == bg;
                      return ChoiceChip(
                        label: Text(bg),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.canvas,
                        labelStyle: AppTypography.caption.copyWith(
                          color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        side: BorderSide.none,
                        onSelected: (selected) {
                          setState(() {
                            _bloodGroupController.text = selected ? bg : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SoftTextField(
                    controller: _allergiesController,
                    labelText: 'Known Drug & Food Allergies',
                    hintText: 'e.g. Penicillin, Peanuts, Sulfa',
                    prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  ),
                  const SizedBox(height: 14),
                  SoftTextField(
                    controller: _emergencyNameController,
                    labelText: 'Emergency Contact Name',
                    hintText: 'e.g. Fatima Begum (Spouse)',
                    prefixIcon: const Icon(Icons.contact_phone_outlined, color: AppColors.accentPink, size: 20),
                  ),
                  const SizedBox(height: 14),
                  SoftTextField(
                    controller: _emergencyPhoneController,
                    labelText: 'Emergency Contact Phone',
                    hintText: '017XXXXXXXX',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_in_talk_outlined, color: AppColors.accentPink, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Save Changes CTA
            SoftPrimaryButton(
              label: 'Save Changes',
              height: 48,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveProfile,
            ),
            const SizedBox(height: 16),

            // Delete Account Link
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                label: Text(
                  'Delete Account',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _showDeleteAccountDialog,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
