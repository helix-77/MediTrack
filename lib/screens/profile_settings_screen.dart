import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/family_member.dart';
import '../services/avatar_service.dart';
import '../services/user_profile_service.dart';
import '../services/family_service.dart';
import '../services/entitlement_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_modal_sheet.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import 'doctor_summary_screen.dart';
import 'prescription_vault_screen.dart';
import 'medicine_search_screen.dart';
import 'nearby_pharmacies_screen.dart';
import 'subscription_offer_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'buy_list_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final UserProfileService _profileService = UserProfileService();
  final FamilyService _familyService = FamilyService();

  int _selectedFilterIndex = 0;

  void _showEditHealthProfileBottomSheet(UserProfile profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloodCtrl = TextEditingController(text: profile.bloodGroup ?? '');
    final allergiesCtrl = TextEditingController(text: profile.allergies ?? '');

    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.7,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
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
                'Clinical Health Profile',
                style: AppTypography.headingMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Important health data for clinical reference & doctor visits',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 20),

              // Blood Group Quick Chips
              Text('Blood Group', style: AppTypography.caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bloodGroups.map((bg) {
                  final isSelected = bloodCtrl.text == bg;
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
                      setModalState(() {
                        bloodCtrl.text = selected ? bg : '';
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              SoftTextField(
                controller: allergiesCtrl,
                labelText: 'Known Allergies',
                hintText: 'e.g. Penicillin, Peanuts, Sulfa',
                prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              ),
              const SizedBox(height: 24),
              SoftPrimaryButton(
                label: 'Save Clinical Profile',
                height: 46,
                onPressed: () async {
                  final updated = profile.copyWith(
                    bloodGroup: bloodCtrl.text.trim().isEmpty ? null : bloodCtrl.text.trim(),
                    allergies: allergiesCtrl.text.trim().isEmpty ? null : allergiesCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  await _profileService.saveProfile(updated);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Health profile updated!'),
                        backgroundColor: AppColors.success,
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

  void _showFamilyMembersBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    bool isAdding = false;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.85,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Family Members',
                          style: AppTypography.headingMedium.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage prescriptions and SMS alerts for family',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(isAdding ? Icons.close : Icons.add, size: 16, color: AppColors.primaryBlue),
                    label: Text(
                      isAdding ? 'Cancel' : 'Add Member',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      setModalState(() {
                        isAdding = !isAdding;
                        if (!isAdding) nameCtrl.clear();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Inline Add Member Field if expanded
              if (isAdding) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.primaryBlueLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SoftTextField(
                        controller: nameCtrl,
                        labelText: 'Member Name & Relation',
                        hintText: 'e.g. Fatima Begum (Mother)',
                        prefixIcon: const Icon(Icons.person_add_outlined, color: AppColors.primaryBlue, size: 20),
                      ),
                      const SizedBox(height: 12),
                      SoftPrimaryButton(
                        label: 'Save Member',
                        height: 40,
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          nameCtrl.clear();
                          setModalState(() => isAdding = false);
                          await _familyService.addFamilyMember(name);
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Stream of Family Members
              Flexible(
                child: StreamBuilder<List<FamilyMember>>(
                  stream: _familyService.streamFamilyMembers(),
                  builder: (context, fSnapshot) {
                    final members = fSnapshot.data ?? [];
                    if (members.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.primaryBlueLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.family_restroom_rounded, color: AppColors.primaryBlue, size: 32),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No family members added yet',
                                style: AppTypography.headingSmall.copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your parents, spouse, or children to track their routines.',
                                textAlign: TextAlign.center,
                                style: AppTypography.caption,
                              ),
                              const SizedBox(height: 14),
                              SoftPrimaryButton(
                                label: '+ Add First Member',
                                height: 38,
                                width: 180,
                                onPressed: () => setModalState(() => isAdding = true),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: members.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = members[index];
                        return SoftSurface(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderRadius: BorderRadius.circular(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.family_restroom_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  m.displayName,
                                  style: AppTypography.headingSmall.copyWith(
                                    fontSize: 15,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.folder_shared_outlined,
                                  color: AppColors.primaryBlue,
                                  size: 22,
                                ),
                                tooltip: 'View Rx Vault',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PrescriptionVaultScreen(
                                        initialFamilyMemberId: m.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                                onPressed: () => _familyService.deleteFamilyMember(m.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entitlement = context.watch<EntitlementService>();
    final avatarNotifier = context.watch<AvatarNotifier>();
    final isPro = entitlement.isSubscribed;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          // Streak / Adherence Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '98%',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Settings Screen Navigation
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.streamProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ??
              UserProfile(
                uid: 'current',
                displayName: 'MediTrack User',
                email: '',
              );

          final initial = profile.displayName.isNotEmpty
              ? profile.displayName[0].toUpperCase()
              : 'U';

          return RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. HERO USER PROFILE CARD
                Center(
                  child: Column(
                    children: [
                      // Large Avatar with Glow and Verified Badge (Tap to Edit)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(profile: profile),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0EDFE),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarNotifier.avatarFile != null
                                    ? Image.file(
                                        avatarNotifier.avatarFile!,
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Text(
                                          initial,
                                          style: AppTypography.displayLarge.copyWith(
                                            color: AppColors.primaryBlue,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User Full Name with Verification
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: AppTypography.headingLarge.copyWith(fontSize: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppColors.primaryBlue, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Phone / Email subtitle
                      Text(
                        profile.bdMobile ?? (profile.email.isNotEmpty ? profile.email : 'Bangladesh'),
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick Action Chips Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFilterChip(
                              index: 0,
                              icon: Icons.edit_outlined,
                              label: 'Edit Profile',
                              isDark: isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditProfileScreen(profile: profile),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            _buildFilterChip(
                              index: 1,
                              icon: Icons.group_outlined,
                              label: 'Family',
                              isDark: isDark,
                              onTap: _showFamilyMembersBottomSheet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. MEDITRACK PREMIUM / BD APPS STATUS
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
                                  ? 'Full AI, OCR & Family SMS alerts active'
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
                const SizedBox(height: 20),

                // 3. HEALTH & CLINICAL PROFILE CARD
                SoftSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  borderRadius: AppRadii.cardRadius,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Health Profile',
                            style: AppTypography.headingSmall.copyWith(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showEditHealthProfileBottomSheet(profile),
                            child: Text(
                              'Edit',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildHealthItemRow(
                        label: 'Blood Group',
                        value: profile.bloodGroup ?? 'Not set',
                        isDark: isDark,
                      ),
                      Divider(
                        height: 20,
                        thickness: 0.8,
                        color: isDark ? AppColors.darkDivider : const Color(0xFFF1F5F9),
                      ),
                      _buildHealthItemRow(
                        label: 'Allergies',
                        value: profile.allergies ?? 'None reported',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. CLINICAL VAULT & MEDICAL TOOLS (Smart Shortcuts)
                SoftSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.shopping_basket_outlined, color: AppColors.primaryBlue),
                        title: Text('Medicine Buy & Restock List', style: AppTypography.bodyMedium),
                        subtitle: Text('Track purchases, refills & medical supplies', style: AppTypography.caption),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BuyListScreen()),
                          );
                        },
                      ),
                      const Divider(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryBlue),
                        title: Text('Generate Doctor Visit Summary', style: AppTypography.bodyMedium),
                        subtitle: Text('Export adherence report for physician', style: AppTypography.caption),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
                          );
                        },
                      ),
                      const Divider(height: 6),
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
                      const Divider(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                        title: Text('Medicine Price & Generic Lookup', style: AppTypography.bodyMedium),
                        subtitle: Text('DGDA Bangladesh database & cheaper brands', style: AppTypography.caption),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MedicineSearchScreen()),
                          );
                        },
                      ),
                      const Divider(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.local_pharmacy_outlined, color: AppColors.primaryBlue),
                        title: Text('Find Nearby 24/7 Pharmacies', style: AppTypography.bodyMedium),
                        subtitle: Text('GPS directions to licensed drugstores', style: AppTypography.caption),
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

                // App Brand & Version Footer
                Center(
                  child: Column(
                    children: [
                      const AppLogo(size: 38, showShadow: false),
                      const SizedBox(height: 8),
                      Text(
                        'MediTrack v0.0.3b (Build 3)',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Smart Health & Generic Companion • Bangladesh',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10.5,
                          color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.6) : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedFilterIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedFilterIndex = index);
          if (onTap != null) onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue
                : (isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthItemRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
