import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../logic/entitlement_guard.dart';
import '../models/family_member.dart';
import '../models/prescription.dart';
import '../models/prescription_extraction.dart';
import '../services/entitlement_service.dart';
import '../services/family_service.dart';
import '../services/prescription_service.dart';
import '../services/prescription_extraction_service.dart';
import '../services/prescription_ocr_service.dart';
import '../logic/image_preflight.dart';
import '../logic/prescription_validator.dart';
import '../l10n/locale_notifier.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/premium_gate.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import '../widgets/status_pill.dart';

class ScanPrescriptionScreen extends StatefulWidget {
  final String? initialFamilyMemberId;

  const ScanPrescriptionScreen({super.key, this.initialFamilyMemberId});

  @override
  State<ScanPrescriptionScreen> createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  final PrescriptionService _prescriptionService = PrescriptionService();
  final FamilyService _familyService = FamilyService();
  final PrescriptionExtractionService _aiService =
      PrescriptionExtractionService();

  File? _capturedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  ImageQualityResult? _qualityResult;
  String? _selectedFamilyMemberId;

  // Metadata form
  final _titleController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _visitDate = DateTime.now();

  List<PrescriptionItem> _extractedReviewItems = [];

  @override
  void initState() {
    super.initState();
    _selectedFamilyMemberId = widget.initialFamilyMemberId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    final entitlementService = context.read<EntitlementService>();
    final allowed = await entitlementService.requirePremium(
      context,
      feature: EntitlementFeature.prescriptionOcr,
    );
    if (!allowed || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    final fileLength = await imageFile.length();

    setState(() {
      _capturedImage = imageFile;
      _qualityResult = null;
      _extractedReviewItems.clear();
      _isAnalyzing = true;
    });

    try {
      final quality = ImagePreflight.evaluate(fileSizeBytes: fileLength);
      setState(() => _qualityResult = quality);

      if (!quality.isAcceptable) {
        setState(() => _isAnalyzing = false);
        return;
      }

      // 1. Run local on-device ML Kit OCR
      PrescriptionOcrResult? ocrResult;
      try {
        final ocrService = PrescriptionOcrService();
        ocrResult = await ocrService.processImage(imageFile);
        ocrService.dispose();
      } catch (ocrErr) {
        debugPrint('On-device OCR scanner error: $ocrErr');
      }

      // 2. Call cloud AI extraction with image + on-device OCR text
      PrescriptionDraft? draft;
      try {
        draft = await _aiService.extractPrescription(
          imageFile: imageFile,
          onDeviceOcrText: ocrResult?.rawText,
        );
      } catch (aiErr) {
        debugPrint('Cloud AI extraction failed: $aiErr');
        // If AI returned unreadable or errored, check if on-device OCR found medicines
        if (ocrResult != null && ocrResult.detectedMedicines.isNotEmpty) {
          final fallbackItems = ocrResult.toPrescriptionItems();
          if (fallbackItems.isNotEmpty) {
            draft = PrescriptionDraft(
              schemaVersion: 1,
              medicines: fallbackItems,
              rawText: ocrResult.rawText,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cloud AI had difficulty with handwriting. Loaded medications detected by on-device scanner for your review.',
                  ),
                  backgroundColor: AppColors.warning,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }

        if (draft == null) {
          String userMessage;
          if (aiErr is PrescriptionExtractionException) {
            switch (aiErr.type) {
              case PrescriptionErrorType.unreadable:
                userMessage =
                    'The image was not recognized as a clear prescription. You can add medicines manually below or retake the photo.';
                break;
              case PrescriptionErrorType.networkTimeout:
                userMessage =
                    'Network connection timed out. You can add medicines manually below or try again.';
                break;
              case PrescriptionErrorType.quotaLimit:
                userMessage =
                    'AI extraction is busy right now. You can enter medicines manually or try again shortly.';
                break;
              default:
                userMessage =
                    'Could not detect medicines automatically. You can add them manually below.';
            }
          } else {
            userMessage =
                'Could not detect medicines automatically. You can add them manually below.';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 4),
              ),
            );
          }

          // Fallback draft so the user can continue and add medicines manually
          draft = PrescriptionDraft(
            schemaVersion: 1,
            medicines: const [],
            rawText: ocrResult?.rawText,
          );
        }
      }

      unawaited(entitlementService.recordPrescriptionScanUsage());

      setState(() {
        if (draft!.doctorName != null && draft.doctorName!.isNotEmpty) {
          _doctorNameController.text = draft.doctorName!;
        }
        if (draft.date != null) {
          final parsedDate = DateTime.tryParse(draft.date!);
          if (parsedDate != null) _visitDate = parsedDate;
        }
        if (_titleController.text.isEmpty) {
          final doc = draft.doctorName != null && draft.doctorName!.isNotEmpty
              ? ' - Dr. ${draft.doctorName}'
              : '';
          _titleController.text =
              'Prescription ${DateFormat("MMM d, yyyy").format(_visitDate)}$doc';
        }

        _extractedReviewItems = List.from(draft.medicines);
      });

      if (draft.medicines.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No medicines detected automatically. Tap "Add Medicine Manually" below to add medications from your prescription.',
            ),
            backgroundColor: AppColors.primaryBlue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notice: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _addNewMedicine() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final formCtrl = TextEditingController(text: 'tablet');
    final durationCtrl = TextEditingController(text: '7');
    final instructionsCtrl = TextEditingController();
    int timesPerDay = 2;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
          title: Text(
            'Add Medicine',
            style: AppTypography.headingMedium,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftTextField(
                  controller: nameCtrl,
                  labelText: 'Medicine Name *',
                  hintText: 'e.g. Napa Extra',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SoftTextField(
                        controller: formCtrl,
                        labelText: 'Form',
                        hintText: 'tablet',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftTextField(
                        controller: dosageCtrl,
                        labelText: 'Dosage / Strength',
                        hintText: '500mg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Times per day',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: timesPerDay,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: [1, 2, 3, 4]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v times'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => timesPerDay = v ?? 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftTextField(
                        controller: durationCtrl,
                        labelText: 'Duration (days)',
                        hintText: '7',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SoftTextField(
                  controller: instructionsCtrl,
                  labelText: 'Instructions',
                  hintText: 'After meal',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a medicine name.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                final newMed = PrescriptionItem(
                  id: '',
                  extractedName: name,
                  extractedForm: formCtrl.text.trim().isEmpty
                      ? 'tablet'
                      : formCtrl.text.trim(),
                  extractedStrength: dosageCtrl.text.trim().isEmpty
                      ? null
                      : dosageCtrl.text.trim(),
                  extractedFrequencyPerDay: timesPerDay,
                  extractedDurationDays: int.tryParse(durationCtrl.text) ?? 7,
                  extractedInstructions: instructionsCtrl.text.trim().isEmpty
                      ? null
                      : instructionsCtrl.text.trim(),
                  confidence: 'high',
                  confirmed: true,
                );
                setState(() {
                  _extractedReviewItems.add(newMed);
                });
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Add Medicine',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeExtractedMedicine(int index) {
    setState(() {
      _extractedReviewItems.removeAt(index);
    });
  }

  void _editExtractedMedicine(int index) {
    final med = _extractedReviewItems[index];
    final nameCtrl = TextEditingController(text: med.extractedName);
    final dosageCtrl = TextEditingController(text: med.extractedStrength ?? '');
    final formCtrl = TextEditingController(text: med.extractedForm ?? 'tablet');
    final durationCtrl = TextEditingController(
      text: med.extractedDurationDays?.toString() ?? '7',
    );
    final instructionsCtrl = TextEditingController(
      text: med.extractedInstructions ?? '',
    );
    int timesPerDay = med.extractedFrequencyPerDay ?? 2;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
          title: Text(
            'Edit Extracted Medicine',
            style: AppTypography.headingMedium,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftTextField(
                  controller: nameCtrl,
                  labelText: 'Medicine Name',
                  hintText: 'e.g. Napa Extra',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SoftTextField(
                        controller: formCtrl,
                        labelText: 'Form',
                        hintText: 'tablet',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftTextField(
                        controller: dosageCtrl,
                        labelText: 'Dosage / Strength',
                        hintText: '500mg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Times per day',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: timesPerDay,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: [1, 2, 3, 4]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v times'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => timesPerDay = v ?? 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftTextField(
                        controller: durationCtrl,
                        labelText: 'Duration (days)',
                        hintText: '7',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SoftTextField(
                  controller: instructionsCtrl,
                  labelText: 'Instructions',
                  hintText: 'After meal',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
              onPressed: () {
                final updatedMed = med.copyWith(
                  extractedName: nameCtrl.text.trim(),
                  extractedForm: formCtrl.text.trim().isEmpty
                      ? null
                      : formCtrl.text.trim(),
                  extractedStrength: dosageCtrl.text.trim().isEmpty
                      ? null
                      : dosageCtrl.text.trim(),
                  extractedFrequencyPerDay: timesPerDay,
                  extractedDurationDays: int.tryParse(durationCtrl.text),
                  extractedInstructions: instructionsCtrl.text.trim().isEmpty
                      ? null
                      : instructionsCtrl.text.trim(),
                );
                setState(() {
                  _extractedReviewItems[index] = updatedMed;
                });
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAll({required bool saveToInventory}) async {
    if (_capturedImage == null) return;
    setState(() => _isSaving = true);

    try {
      final prescription = Prescription(
        id: '',
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Prescription ${DateFormat("MMM d, yyyy").format(_visitDate)}',
        doctorName: _doctorNameController.text.trim().isNotEmpty
            ? _doctorNameController.text.trim()
            : null,
        date: _visitDate,
        notes: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        extractedText: _extractedReviewItems
            .map((m) => '${m.extractedName} ${m.extractedStrength ?? ""}')
            .join(', '),
        familyMemberId: _selectedFamilyMemberId,
        createdAt: DateTime.now(),
      );

      final savedRx = await _prescriptionService.savePrescriptionWithItems(
        prescription,
        _extractedReviewItems,
        _capturedImage,
      );

      if (saveToInventory) {
        await _prescriptionService.confirmAndPersistMedicines(
          prescriptionId: savedRx.id,
          items: _extractedReviewItems,
          prescriptionImageUrl: savedRx.imageUrl,
          familyMemberId: _selectedFamilyMemberId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saveToInventory
                  ? '✅ Prescription & confirmed medicines saved to routine!'
                  : '✅ Prescription image saved to digital vault!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, savedRx);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGate(
      feature: EntitlementFeature.prescriptionOcr,
      builder: _buildScreen,
    );
  }

  Widget _buildScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Scan Prescription'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Capture Box
            _buildImageCaptureBox(isDark),
            const SizedBox(height: 18),

            // Preflight Quality Result
            if (_qualityResult != null) ...[
              _buildQualityBanner(_qualityResult!, isDark),
              const SizedBox(height: 18),
            ],

            // Analyzing Indicator
            if (_isAnalyzing) ...[
              SoftCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing Prescription with Gemini AI...',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Extracting doctor info, dosage instructions, and schedules.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Extracted Medicines Section
            if (_extractedReviewItems.isNotEmpty) ...[
              SectionHeader(
                title: 'Extracted Medicines (${_extractedReviewItems.length})',
                subtitle:
                    'Review and confirm medicines to add to your daily schedule',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        final allSelected = _extractedReviewItems.every(
                          (i) => i.confirmed,
                        );
                        setState(() {
                          _extractedReviewItems = _extractedReviewItems
                              .map((item) => item.copyWith(confirmed: !allSelected))
                              .toList();
                        });
                      },
                      child: Text(
                        _extractedReviewItems.every((i) => i.confirmed)
                            ? 'Deselect All'
                            : 'Select All',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _addNewMedicine,
                      icon: const Icon(Icons.add, size: 16, color: AppColors.primaryBlue),
                      label: Text(
                        'Add Med',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ..._extractedReviewItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return _buildExtractedMedCard(item, idx, isDark);
              }),
              const SizedBox(height: 24),
            ] else if (_capturedImage != null && !_isAnalyzing) ...[
              SoftSurface(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlueLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No medicines listed yet',
                      style: AppTypography.headingSmall.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If handwriting was unclear or no medicines were detected, you can add medications manually from your prescription.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 16),
                    SoftPrimaryButton(
                      label: 'Add Medicine Manually',
                      icon: Icons.add_rounded,
                      height: 44,
                      onPressed: _addNewMedicine,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Prescription Metadata Form
            if (_capturedImage != null && !_isAnalyzing) ...[
              const SectionHeader(
                title: 'Prescription Details',
                subtitle: 'Add physician details for clinical record-keeping',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    SoftTextField(
                      controller: _titleController,
                      labelText: 'Prescription Title',
                      hintText: 'e.g. Cardiology Visit',
                    ),
                    const SizedBox(height: 14),
                    SoftTextField(
                      controller: _doctorNameController,
                      labelText: 'Doctor Name',
                      hintText: 'e.g. Prof. Ahmed',
                    ),
                    const SizedBox(height: 14),
                    SoftTextField(
                      controller: _noteController,
                      labelText: context.tr('prescription_note_label'),
                      hintText: context.tr('prescription_note_hint'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Consultation Date',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('dd MMMM yyyy').format(_visitDate),
                        style: AppTypography.caption,
                      ),
                      trailing: SoftIconButton(
                        icon: Icons.calendar_today_rounded,
                        iconColor: AppColors.primaryBlue,
                        size: 38,
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _visitDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 730),
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _visitDate = picked);
                          }
                        },
                      ),
                    ),
                    _buildFamilyMemberSelector(isDark),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (_extractedReviewItems.isNotEmpty) ...[
                SoftPrimaryButton(
                  label: 'Save & Add Confirmed to Routine',
                  isLoading: _isSaving,
                  onPressed: _isSaving
                      ? null
                      : () => _saveAll(saveToInventory: true),
                ),
                const SizedBox(height: 12),
              ],
              SoftSecondaryButton(
                label: 'Save Photo to Vault Only',
                onPressed: _isSaving
                    ? null
                    : () => _saveAll(saveToInventory: false),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCaptureBox(bool isDark) {
    if (_capturedImage != null) {
      return SoftSurface(
        padding: const EdgeInsets.all(12),
        borderRadius: AppRadii.cardRadius,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _capturedImage!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SoftSecondaryButton(
                    label: 'Retake Camera',
                    icon: Icons.camera_alt_outlined,
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftSecondaryButton(
                    label: 'From Gallery',
                    icon: Icons.photo_library_outlined,
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SoftSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      borderRadius: AppRadii.cardRadius,
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 36,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text('Capture Prescription', style: AppTypography.headingMedium),
            const SizedBox(height: 6),
            Text(
              'Take a clear photo in good lighting to let Gemini AI extract medications and doctor instructions.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final entitlement = context.watch<EntitlementService>();
                if (entitlement.isSubscribed) return const SizedBox.shrink();
                final remaining = entitlement.freePrescriptionScansRemaining;
                final isAvailable = remaining > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? (isDark ? const Color(0xFF132A38) : const Color(0xFFE0F2FE))
                        : (isDark ? const Color(0xFF2B2215) : AppColors.warningLight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.stars_rounded : Icons.lock_outline_rounded,
                        size: 15,
                        color: isAvailable
                            ? (isDark ? const Color(0xFF7DD3FC) : AppColors.primaryBlueDark)
                            : (isDark ? const Color(0xFFFBBF24) : AppColors.warning),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable
                            ? '✨ Free Trial: 1 Free AI Scan available'
                            : 'Free scan used • Upgrade for unlimited scans',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isAvailable
                              ? (isDark ? const Color(0xFF7DD3FC) : AppColors.primaryBlueDark)
                              : (isDark ? const Color(0xFFFBBF24) : AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SoftPrimaryButton(
                    label: 'Take Photo',
                    icon: Icons.camera_alt_rounded,
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftSecondaryButton(
                    label: 'Choose Gallery',
                    icon: Icons.image_outlined,
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityBanner(ImageQualityResult quality, bool isDark) {
    final isPassed = quality.isAcceptable;
    final bg = isPassed
        ? (isDark ? const Color(0xFF152A1E) : AppColors.successLight)
        : (isDark ? const Color(0xFF2B2215) : AppColors.warningLight);
    final border = isPassed ? AppColors.success : AppColors.warning;

    return SoftSurface(
      padding: const EdgeInsets.all(14),
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPassed
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            color: border,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPassed ? 'Image Quality Passed' : 'Image Quality Warning',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 14,
                    color: border,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPassed
                      ? 'Image is sharp and clear for extraction.'
                      : (quality.warningMessage ??
                            'Please retake with good lighting to avoid OCR mistakes.'),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedMedCard(PrescriptionItem med, int index, bool isDark) {
    PillType confType;
    if (med.confidence.toLowerCase() == 'high') {
      confType = PillType.success;
    } else if (med.confidence.toLowerCase() == 'medium') {
      confType = PillType.warning;
    } else {
      confType = PillType.danger;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SoftSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: med.confirmed,
              activeColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (val) {
                setState(() {
                  _extractedReviewItems[index] = med.copyWith(
                    confirmed: val ?? true,
                  );
                });
              },
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          med.extractedName,
                          style: AppTypography.headingSmall.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                      StatusPill(
                        label: med.confidence.toUpperCase(),
                        type: confType,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${med.extractedForm ?? "Tablet"} • ${med.extractedStrength ?? "N/A"} • ${med.extractedFrequencyPerDay ?? 2} times/day • ${med.extractedDurationDays ?? "Ongoing"} days',
                    style: AppTypography.caption,
                  ),
                  if (med.extractedInstructions != null &&
                      med.extractedInstructions!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Instructions: ${med.extractedInstructions}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                  onPressed: () => _editExtractedMedicine(index),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  onPressed: () => _removeExtractedMedicine(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMemberSelector(bool isDark) {
    return StreamBuilder<List<FamilyMember>>(
      stream: _familyService.streamFamilyMembers(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            Text(
              'Assign to Family Member',
              style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Myself'),
                  selected: _selectedFamilyMemberId == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedFamilyMemberId = null);
                  },
                ),
                ...members.map(
                  (m) => ChoiceChip(
                    label: Text(m.displayName),
                    selected: _selectedFamilyMemberId == m.id,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFamilyMemberId = selected ? m.id : null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
