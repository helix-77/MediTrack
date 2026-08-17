import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';

import '../logic/entitlement_guard.dart';
import '../logic/image_preflight.dart';
import '../logic/prescription_validator.dart';
import '../models/prescription.dart';
import '../models/prescription_extraction.dart';
import '../services/entitlement_service.dart';
import '../services/prescription_extraction_service.dart';
import '../services/prescription_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ScanPrescriptionScreen extends StatefulWidget {
  final File? initialImage;

  const ScanPrescriptionScreen({super.key, this.initialImage});

  @override
  State<ScanPrescriptionScreen> createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  final PrescriptionService _prescriptionService = PrescriptionService();
  final PrescriptionExtractionService _aiService = PrescriptionExtractionService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _isExtracting = false;
  bool _isSaving = false;
  String? _preflightWarning;
  String? _errorMessage;

  final _titleController = TextEditingController();
  final _doctorController = TextEditingController();
  final _patientController = TextEditingController();
  final _notesController = TextEditingController();
  final DateTime _prescriptionDate = DateTime.now();

  List<PrescriptionItem> _extractedItems = [];
  String? _rawExtractionText;

  @override
  void initState() {
    super.initState();
    _titleController.text =
        'Prescription ${DateFormat('MMM d, yyyy').format(DateTime.now())}';
    if (widget.initialImage != null) {
      _imageFile = widget.initialImage;
      _preflightImage(_imageFile!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _patientController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<ImageQualityResult> _preflightImage(File file) async {
    final size = await file.length();
    final preflight = ImagePreflight.evaluate(fileSizeBytes: size);
    if (mounted) {
      setState(() {
        _preflightWarning = preflight.warningMessage;
      });
    }
    return preflight;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked != null) {
      final file = File(picked.path);
      setState(() {
        _imageFile = file;
        _errorMessage = null;
      });
      await _preflightImage(file);
      await _runExtraction(file);
    }
  }

  Future<void> _runExtraction(File file) async {
    // Preflight quality check
    final preflight = await _preflightImage(file);
    if (!preflight.isAcceptable) {
      if (mounted) {
        setState(() {
          _errorMessage = preflight.warningMessage;
        });
      }
      return;
    }

    if (!mounted) return;
    final entitlement = context.read<EntitlementService>();
    final isAllowed = await entitlement.requirePremium(
      context,
      feature: EntitlementFeature.prescriptionOcr,
    );
    if (!isAllowed || !mounted) {
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final draft = await _aiService.extractPrescription(imageFile: file);
      await entitlement.recordPrescriptionScanUsage();
      if (!mounted) return;
      setState(() {
        if (draft.doctorName != null && draft.doctorName!.isNotEmpty) {
          _doctorController.text = draft.doctorName!;
        }
        if (draft.patientName != null && draft.patientName!.isNotEmpty) {
          _patientController.text = draft.patientName!;
        }
        _extractedItems = draft.medicines;
        _rawExtractionText = draft.rawText;
      });
    } on PrescriptionExtractionException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected extraction error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  void _editItemDialog(int index) {
    final item = _extractedItems[index];
    final nameController = TextEditingController(text: item.extractedName);
    final strengthController = TextEditingController(text: item.extractedStrength ?? '');
    final formController = TextEditingController(text: item.extractedForm ?? '');
    final freqController = TextEditingController(
        text: item.extractedFrequencyPerDay != null ? '${item.extractedFrequencyPerDay}' : '');
    final durationController = TextEditingController(
        text: item.extractedDurationDays != null ? '${item.extractedDurationDays}' : '');
    final instructionsController = TextEditingController(text: item.extractedInstructions ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Medicine Item', style: AppTypography.headingSmall),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: strengthController,
                decoration: const InputDecoration(labelText: 'Strength (e.g. 500 mg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: formController,
                decoration: const InputDecoration(labelText: 'Form (e.g. tablet, syrup)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: freqController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Frequency per day (1-6)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration in days'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                decoration: const InputDecoration(labelText: 'Instructions (e.g. after meal)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;

              final updated = item.copyWith(
                extractedName: newName,
                extractedStrength:
                    strengthController.text.trim().isEmpty ? null : strengthController.text.trim(),
                extractedForm:
                    formController.text.trim().isEmpty ? null : formController.text.trim(),
                extractedFrequencyPerDay: int.tryParse(freqController.text.trim()),
                extractedDurationDays: int.tryParse(durationController.text.trim()),
                extractedInstructions:
                    instructionsController.text.trim().isEmpty ? null : instructionsController.text.trim(),
              );

              setState(() {
                _extractedItems[index] = updated;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePhotoOnly() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a prescription title'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final pres = Prescription(
        id: '',
        title: title,
        doctorName: _doctorController.text.trim().isEmpty ? null : _doctorController.text.trim(),
        date: _prescriptionDate,
        extractedText: _rawExtractionText ?? '',
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        status: 'draft',
        createdAt: DateTime.now(),
      );

      await _prescriptionService.savePrescription(pres, _imageFile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription photo saved to Vault!'),
          backgroundColor: AppColors.success,
        ),
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

  Future<void> _saveAndConfirmMedicines() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a prescription title'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmedItems = _extractedItems.where((i) => i.confirmed).toList();

    setState(() => _isSaving = true);
    try {
      final pres = Prescription(
        id: '',
        title: title,
        doctorName: _doctorController.text.trim().isEmpty ? null : _doctorController.text.trim(),
        date: _prescriptionDate,
        extractedText: _rawExtractionText ?? '',
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        status: confirmedItems.isNotEmpty ? 'reviewed' : 'draft',
        createdAt: DateTime.now(),
      );

      final saved = await _prescriptionService.savePrescriptionWithItems(
        pres,
        _extractedItems,
        _imageFile,
      );

      if (confirmedItems.isNotEmpty) {
        await _prescriptionService.confirmAndPersistMedicines(
          prescriptionId: saved.id,
          items: confirmedItems,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmedItems.isNotEmpty
                ? 'Prescription saved & ${confirmedItems.length} medicine(s) added to routine!'
                : 'Prescription draft saved to Vault!',
          ),
          backgroundColor: AppColors.success,
        ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Scan Prescription',
          style: AppTypography.headingMedium.copyWith(color: AppColors.primaryGreen),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Image Picker Area
          _buildImageCard(),
          const SizedBox(height: 16),

          // Quality Warning Banner
          if (_preflightWarning != null) _buildWarningBanner(_preflightWarning!),

          // Loading Indicator
          if (_isExtracting) _buildExtractingIndicator(),

          // Error Message Banner
          if (_errorMessage != null && !_isExtracting) _buildErrorBanner(_errorMessage!),

          // Extracted Items Section
          if (_extractedItems.isNotEmpty && !_isExtracting) ...[
            _buildDisclaimerBanner(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extracted Medicines (${_extractedItems.length})',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final allChecked = _extractedItems.every((i) => i.confirmed);
                    setState(() {
                      _extractedItems = _extractedItems
                          .map((i) => i.copyWith(confirmed: !allChecked))
                          .toList();
                    });
                  },
                  child: Text(
                    _extractedItems.every((i) => i.confirmed)
                        ? 'Uncheck All'
                        : 'Check All',
                    style: const TextStyle(color: AppColors.primaryGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._extractedItems.asMap().entries.map((entry) {
              return _buildItemCard(entry.key, entry.value);
            }),
            const SizedBox(height: 20),
          ],

          // Prescription Meta Form Fields
          _buildMetaFields(),
          const SizedBox(height: 24),

          // Action Buttons
          _buildActionButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return GestureDetector(
      onTap: _showSourcePickerModal,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            width: 1.5,
          ),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
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
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      size: 36,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to capture or upload prescription',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI Gemini 3.6 Flash will extract medicines & dosages',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildExtractingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(color: AppColors.primaryGreen),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Extracting prescription details...',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Analyzing handwriting and dosages with Gemini AI',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String warning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text('Extraction Failed',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(error, style: AppTypography.bodySmall),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_imageFile != null)
                OutlinedButton(
                  onPressed: () => _runExtraction(_imageFile!),
                  child: const Text('Retry Scan'),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _savePhotoOnly,
                child: const Text('Save Photo Only'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentPinkLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI extraction may make mistakes. Please verify every dosage and medicine against the physical prescription.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, PrescriptionItem item) {
    final Color confidenceColor = switch (item.confidence) {
      'high' => AppColors.success,
      'low' => AppColors.danger,
      _ => AppColors.warning,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: item.confirmed,
              activeColor: AppColors.primaryGreen,
              onChanged: (val) {
                setState(() {
                  _extractedItems[index] = item.copyWith(confirmed: val ?? false);
                });
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.extractedName,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: confidenceColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.confidence.toUpperCase()} CONFIDENCE',
                          style: TextStyle(
                            color: confidenceColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (item.extractedStrength != null)
                        _buildChip(item.extractedStrength!),
                      if (item.extractedForm != null) _buildChip(item.extractedForm!),
                      if (item.extractedFrequencyPerDay != null)
                        _buildChip('${item.extractedFrequencyPerDay}x / day'),
                      if (item.extractedDurationDays != null)
                        _buildChip('${item.extractedDurationDays} days'),
                    ],
                  ),
                  if (item.extractedInstructions != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Instructions: ${item.extractedInstructions}',
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryGreen),
              onPressed: () => _editItemDialog(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11)),
    );
  }

  Widget _buildMetaFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prescription Details',
              style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title / Label *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _doctorController,
            decoration: const InputDecoration(
              labelText: 'Doctor Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            onPressed: _isSaving ? null : _saveAndConfirmMedicines,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Save & Add Confirmed to Routine',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            onPressed: _isSaving ? null : _savePhotoOnly,
            child: const Text(
              'Save Photo to Vault Only',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSourcePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
