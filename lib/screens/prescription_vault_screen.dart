import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/family_member.dart';
import '../models/prescription.dart';
import '../models/prescription_extraction.dart';
import '../services/family_service.dart';
import '../services/prescription_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import '../widgets/soft_modal_sheet.dart';
import 'scan_prescription_screen.dart';

class PrescriptionVaultScreen extends StatefulWidget {
  final String? initialFamilyMemberId;

  const PrescriptionVaultScreen({super.key, this.initialFamilyMemberId});

  @override
  State<PrescriptionVaultScreen> createState() => _PrescriptionVaultScreenState();
}

class _PrescriptionVaultScreenState extends State<PrescriptionVaultScreen> {
  final PrescriptionService _prescriptionService = PrescriptionService();
  final FamilyService _familyService = FamilyService();
  late String _selectedFamilyMemberId;

  @override
  void initState() {
    super.initState();
    _selectedFamilyMemberId = widget.initialFamilyMemberId ?? 'self';
  }

  void _showPrescriptionViewer(Prescription rx, Map<String, String> memberNameMap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patientLabel = rx.familyMemberId != null
        ? (memberNameMap[rx.familyMemberId] ?? 'Family Member')
        : 'Myself';

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.85,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rx.title,
                        style: AppTypography.headingMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (rx.doctorName != null) ...[
                            Text(
                              'Dr. ${rx.doctorName!}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              'Patient: $patientLabel',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SoftIconButton(
                  icon: Icons.close_rounded,
                  size: 36,
                  iconSize: 18,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Flexible(
            fit: FlexFit.loose,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              physics: const BouncingScrollPhysics(),
              children: [
                Text(
                  'Consultation Date: ${DateFormat('dd MMMM yyyy').format(rx.date)}',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 12),

                // Image Viewer
                ClipRRect(
                  borderRadius: AppRadii.cardRadius,
                  child: _buildPrescriptionImage(
                    rx.imageUrl,
                    fit: BoxFit.contain,
                    interactive: true,
                  ),
                ),

                const SizedBox(height: 20),

                // Extracted Items from subcollection
                StreamBuilder<List<PrescriptionItem>>(
                  stream: _prescriptionService.streamPrescriptionItems(rx.id),
                  builder: (context, itemSnapshot) {
                    final items = itemSnapshot.data ?? [];
                    if (items.isEmpty) {
                      if (rx.extractedText.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                              title: 'Extracted Notes',
                              subtitle: 'Transcribed text from prescription',
                            ),
                            SoftSurface(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                rx.extractedText,
                                style: AppTypography.bodySmall,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Extracted Medicines (${items.length})',
                          subtitle: 'Medicines transcribed by AI',
                        ),
                        ...items.map(
                          (m) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: SoftSurface(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.medication_rounded, color: AppColors.primaryBlue, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.extractedName, style: AppTypography.headingSmall.copyWith(fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${m.extractedForm ?? "Tablet"} • ${m.extractedStrength ?? "N/A"} • ${m.extractedFrequencyPerDay ?? 2} times/day',
                                          style: AppTypography.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (m.confirmed)
                                    const StatusPill(label: 'Added', type: PillType.success),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Prescription rx) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Delete Prescription', style: AppTypography.headingMedium),
        content: Text(
          'Are you sure you want to delete "${rx.title}" from your digital vault?',
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
              await _prescriptionService.deletePrescription(rx.id, rx.imageUrl);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<Prescription> _filterPrescriptions(List<Prescription> all) {
    if (_selectedFamilyMemberId == 'self') {
      return all.where((p) => p.familyMemberId == null).toList();
    } else {
      return all
          .where((p) => p.familyMemberId == _selectedFamilyMemberId)
          .toList();
    }
  }

  Widget _buildFamilyFilterChips(List<FamilyMember> members, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChipItem(
            label: 'Myself',
            isSelected: _selectedFamilyMemberId == 'self',
            onSelected: () => setState(() => _selectedFamilyMemberId = 'self'),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          ...members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildFilterChipItem(
                label: m.displayName,
                isSelected: _selectedFamilyMemberId == m.id,
                onSelected: () {
                  setState(() {
                    _selectedFamilyMemberId = m.id;
                  });
                },
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipItem({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? AppShadows.subtle
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    List<FamilyMember> members,
    Map<String, String> memberNameMap,
  ) {
    String title;
    String description;
    String buttonLabel;

    if (_selectedFamilyMemberId == 'self') {
      title = 'Your Vault is Empty';
      description =
          'Keep your doctor prescriptions, diagnostic reports, and medical advice safely organized in one place.';
      buttonLabel = 'Scan Prescription for Myself';
    } else if (_selectedFamilyMemberId != null) {
      final name = memberNameMap[_selectedFamilyMemberId] ?? 'Family Member';
      title = 'No Prescriptions for $name';
      description =
          'Store and track $name\'s doctor prescriptions, dosage plans, and medical records.';
      buttonLabel = 'Scan Prescription for $name';
    } else {
      title = 'Your Vault is Empty';
      description =
          'Keep your doctor prescriptions, diagnostic reports, and medical advice safely organized in one place.';
      buttonLabel = 'Scan First Prescription';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: EmptyStateView(
          icon: Icons.folder_shared_outlined,
          title: title,
          description: description,
          buttonLabel: buttonLabel,
          onButtonPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScanPrescriptionScreen(
                  initialFamilyMemberId: _selectedFamilyMemberId == 'self'
                      ? null
                      : _selectedFamilyMemberId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Prescription Vault'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SoftIconButton(
              icon: Icons.add_a_photo_outlined,
              size: 40,
              iconColor: AppColors.primaryBlue,
              tooltip: 'Scan New',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanPrescriptionScreen(
                      initialFamilyMemberId: _selectedFamilyMemberId == 'self'
                          ? null
                          : _selectedFamilyMemberId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<FamilyMember>>(
        stream: _familyService.streamFamilyMembers(),
        builder: (context, familySnapshot) {
          final familyMembers = familySnapshot.data ?? [];
          final memberNameMap = {
            for (final m in familyMembers) m.id: m.displayName,
          };

          return StreamBuilder<List<Prescription>>(
            stream: _prescriptionService.streamPrescriptions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryBlue),
                );
              }

              final allPrescriptions = snapshot.data ?? [];
              final prescriptions = _filterPrescriptions(allPrescriptions);

              return Column(
                children: [
                  if (familyMembers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: _buildFamilyFilterChips(familyMembers, isDark),
                    ),
                  Expanded(
                    child: prescriptions.isEmpty
                        ? _buildEmptyState(familyMembers, memberNameMap)
                        : GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: prescriptions.length,
                            itemBuilder: (context, index) {
                              final rx = prescriptions[index];
                              return _buildVaultGridCard(
                                rx,
                                isDark,
                                memberNameMap,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVaultGridCard(
    Prescription rx,
    bool isDark,
    Map<String, String> memberNameMap,
  ) {
    final patientName = rx.familyMemberId != null
        ? (memberNameMap[rx.familyMemberId] ?? 'Family')
        : 'Myself';

    return SoftSurface(
      padding: EdgeInsets.zero,
      borderRadius: AppRadii.cardRadius,
      onTap: () => _showPrescriptionViewer(rx, memberNameMap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Preview
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: _buildPrescriptionImage(
                    rx.imageUrl,
                    fit: BoxFit.cover,
                    interactive: false,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: SoftIconButton(
                    icon: Icons.delete_outline,
                    size: 32,
                    iconSize: 16,
                    iconColor: AppColors.danger,
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    onPressed: () => _confirmDelete(rx),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rx.title,
                  style: AppTypography.headingSmall.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  rx.doctorName != null
                      ? 'Dr. ${rx.doctorName!}'
                      : 'Doctor Visit',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      rx.familyMemberId != null
                          ? Icons.family_restroom_rounded
                          : Icons.person_outline_rounded,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        patientName,
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(rx.date),
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                    StatusPill(
                      label: rx.status.toUpperCase(),
                      type: rx.status == 'reviewed'
                          ? PillType.success
                          : PillType.neutral,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionImage(
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
    bool interactive = false,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: interactive ? 180 : null,
        color: AppColors.canvas,
        child: const Center(
          child: Icon(Icons.receipt_long, size: 40, color: AppColors.primaryBlue),
        ),
      );
    }

    Widget imageWidget;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      imageWidget = Image.network(
        imageUrl,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: interactive ? 250 : null,
            color: AppColors.canvas,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: interactive ? 200 : null,
          color: AppColors.canvas,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textMuted),
          ),
        ),
      );
    } else {
      final file = File(imageUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            height: interactive ? 200 : null,
            color: AppColors.canvas,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textMuted),
            ),
          ),
        );
      } else {
        imageWidget = Container(
          height: interactive ? 180 : null,
          color: AppColors.canvas,
          child: const Center(
            child: Icon(Icons.receipt_long, size: 40, color: AppColors.primaryBlue),
          ),
        );
      }
    }

    if (interactive) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
