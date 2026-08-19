import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/prescription.dart';
import '../models/prescription_extraction.dart';
import '../services/prescription_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import 'scan_prescription_screen.dart';

class PrescriptionVaultScreen extends StatefulWidget {
  const PrescriptionVaultScreen({super.key});

  @override
  State<PrescriptionVaultScreen> createState() => _PrescriptionVaultScreenState();
}

class _PrescriptionVaultScreenState extends State<PrescriptionVaultScreen> {
  final PrescriptionService _prescriptionService = PrescriptionService();

  void _showPrescriptionViewer(Prescription rx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurface
                : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      rx.title,
                      style: AppTypography.headingMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (rx.doctorName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Doctor: Dr. ${rx.doctorName!}',
                  style: AppTypography.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Consultation Date: ${DateFormat('dd MMMM yyyy').format(rx.date)}',
                style: AppTypography.caption,
              ),
              const Divider(height: 24),

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
              const SizedBox(height: 20),
            ],
          ),
        ),
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
                  MaterialPageRoute(builder: (_) => const ScanPrescriptionScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Prescription>>(
        stream: _prescriptionService.streamPrescriptions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            );
          }

          final prescriptions = snapshot.data ?? [];

          if (prescriptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: EmptyStateView(
                  icon: Icons.folder_shared_outlined,
                  title: 'Your Vault is Empty',
                  description: 'Keep your doctor prescriptions, diagnostic reports, and medical advice safely organized in one place.',
                  buttonLabel: 'Scan First Prescription',
                  onButtonPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanPrescriptionScreen()),
                    );
                  },
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final rx = prescriptions[index];
              return _buildVaultGridCard(rx, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildVaultGridCard(Prescription rx, bool isDark) {
    return SoftSurface(
      padding: EdgeInsets.zero,
      borderRadius: AppRadii.cardRadius,
      onTap: () => _showPrescriptionViewer(rx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Preview
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                  rx.doctorName != null ? 'Dr. ${rx.doctorName!}' : 'Doctor Visit',
                  style: AppTypography.caption.copyWith(color: AppColors.primaryBlue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      type: rx.status == 'reviewed' ? PillType.success : PillType.neutral,
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
