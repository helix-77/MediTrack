import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/prescription.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../services/prescription_service.dart';
import '../services/prescription_ocr_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'add_edit_medicine_screen.dart';

class ScanPrescriptionScreen extends StatefulWidget {
  final File? initialImage;

  const ScanPrescriptionScreen({super.key, this.initialImage});

  @override
  State<ScanPrescriptionScreen> createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  final PrescriptionService _prescriptionService = PrescriptionService();
  final PrescriptionOcrService _ocrService = PrescriptionOcrService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _isProcessingOcr = false;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _doctorController = TextEditingController();
  final _notesController = TextEditingController();
  String _extractedText = '';
  List<String> _detectedMedicines = [];
  DateTime _prescriptionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Prescription ${DateFormat('MMM d, yyyy').format(DateTime.now())}';
    if (widget.initialImage != null) {
      _imageFile = widget.initialImage;
      _processImage(_imageFile!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _notesController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      final file = File(picked.path);
      setState(() => _imageFile = file);
      await _processImage(file);
    }
  }

  Future<void> _processImage(File file) async {
    setState(() => _isProcessingOcr = true);
    try {
      final result = await _ocrService.processImage(file);
      setState(() {
        _extractedText = result.rawText;
        _detectedMedicines = result.detectedMedicines;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  Future<void> _savePrescription() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prescription title'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final prescription = Prescription(
        id: '',
        title: title,
        doctorName: _doctorController.text.trim().isEmpty ? null : _doctorController.text.trim(),
        date: _prescriptionDate,
        extractedText: _extractedText,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _prescriptionService.savePrescription(prescription, _imageFile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription saved to Digital Vault!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Prescription', style: AppTypography.headingLarge.copyWith(color: AppColors.primaryGreen)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Image Selection Card / Preview
          GestureDetector(
            onTap: () => _showSourcePickerModal(),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 1.5),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_imageFile!, fit: BoxFit.cover),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: CircleAvatar(
                              backgroundColor: AppColors.primaryGreen,
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.accentPinkLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.document_scanner, size: 40, color: AppColors.primaryGreen),
                        ),
                        const SizedBox(height: 12),
                        Text('Tap to Scan Prescription', style: AppTypography.headingSmall),
                        const SizedBox(height: 4),
                        Text('Take photo or choose from gallery', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // OCR Processing Banner
          if (_isProcessingOcr) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentPinkLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
                  const SizedBox(width: 12),
                  Text('Reading prescription text with ML Kit...', style: AppTypography.bodyMedium.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Form Fields
          Text('Prescription Information', style: AppTypography.headingSmall),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Prescription Title'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _doctorController,
            decoration: const InputDecoration(labelText: 'Doctor Name / Clinic (Optional)'),
          ),
          const SizedBox(height: 12),

          // Date Picker Tile
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prescription Date'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_prescriptionDate)),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _prescriptionDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1095)),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _prescriptionDate = date);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Detected Medicines Section
          if (_detectedMedicines.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Detected Medicines (${_detectedMedicines.length})', style: AppTypography.headingSmall),
                Text('Tap + to add', style: AppTypography.bodySmall.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _detectedMedicines
                  .map(
                    (medText) => ActionChip(
                      avatar: const Icon(Icons.add_task, size: 16, color: AppColors.primaryGreen),
                      label: Text(medText),
                      backgroundColor: AppColors.accentPinkLight,
                      onPressed: () {
                        final draftMed = Medicine(
                          id: '',
                          name: medText,
                          quantityCurrent: 30,
                          quantityTotal: 30,
                          lowStockThreshold: 10,
                          schedule: MedicineSchedule(
                            doseAmount: 1,
                            timesPerDay: 1,
                            doseTimes: ['08:00'],
                            daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
                            startDate: DateTime.now(),
                          ),
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditMedicineScreen(medicine: draftMed),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Extracted Text Expansion Tile
          if (_extractedText.isNotEmpty) ...[
            ExpansionTile(
              title: const Text('Recognized Prescription Text'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    _extractedText,
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes / Special Instructions'),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePrescription,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save to Digital Vault'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSourcePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Prescription Image Source', style: AppTypography.headingSmall),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
