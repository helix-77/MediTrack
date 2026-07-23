import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/prescription.dart';
import '../services/prescription_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'scan_prescription_screen.dart';

class PrescriptionVaultScreen extends StatefulWidget {
  const PrescriptionVaultScreen({super.key});

  @override
  State<PrescriptionVaultScreen> createState() => _PrescriptionVaultScreenState();
}

class _PrescriptionVaultScreenState extends State<PrescriptionVaultScreen> {
  final PrescriptionService _prescriptionService = PrescriptionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Digital Prescription Vault', style: AppTypography.headingLarge.copyWith(color: AppColors.primaryGreen)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanPrescriptionScreen()),
          );
        },
        icon: const Icon(Icons.document_scanner),
        label: const Text('Scan Prescription'),
      ),
      body: StreamBuilder<List<Prescription>>(
        stream: _prescriptionService.streamPrescriptions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final prescriptions = snapshot.data ?? [];

          if (prescriptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.accentPinkLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.folder_shared_outlined, size: 56, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(height: 16),
                    Text('No Prescriptions Stored Yet', style: AppTypography.headingMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Scan written prescriptions with your camera to extract medicines and save them securely in your digital vault.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanPrescriptionScreen()),
                        );
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Scan Your First Prescription'),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prescriptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = prescriptions[index];
              return _buildPrescriptionCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildPrescriptionCard(Prescription item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openPrescriptionViewerModal(item),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image Header
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.accentPinkLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.description, size: 48, color: AppColors.primaryGreen),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.receipt_long, size: 48, color: AppColors.primaryGreen),
                      ),
              ),
            ),
            // Information Body
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headingSmall.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.doctorName ?? DateFormat('MMM d, yyyy').format(item.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPrescriptionViewerModal(Prescription item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Bottom Sheet Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: AppTypography.headingMedium),
                        Text(
                          '${item.doctorName ?? "Prescription"} • ${DateFormat('yyyy-MM-dd').format(item.date)}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete Prescription'),
                          content: Text('Delete "${item.title}" from your digital vault?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _prescriptionService.deletePrescription(item.id, item.imageUrl);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            // Zoomable Interactive Photo
            Expanded(
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.network(item.imageUrl!, fit: BoxFit.contain),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, size: 64, color: AppColors.primaryGreen),
                          const SizedBox(height: 12),
                          Text('No Photo Attached', style: AppTypography.headingSmall),
                        ],
                      ),
                    ),
            ),
            // OCR Text Section
            if (item.extractedText.isNotEmpty)
              ExpansionTile(
                title: const Text('Extracted OCR Text'),
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: SelectableText(item.extractedText, style: AppTypography.bodySmall),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
