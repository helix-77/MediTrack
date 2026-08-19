import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../models/family_member.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../services/family_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/time_formatter.dart';
import '../utils/voice_input_helper.dart';
import '../logic/ocr_parser.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import '../widgets/soft_modal_sheet.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicine;

  const AddEditMedicineScreen({super.key, this.medicine});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final MedicineService _medicineService = MedicineService();
  final NotificationService _notificationService = NotificationService();
  final FamilyService _familyService = FamilyService();
  final VoiceInputHelper _voiceHelper = VoiceInputHelper();

  late TextEditingController _nameController;
  late TextEditingController _genericNameController;
  late TextEditingController _strengthController;
  late TextEditingController _quantityCurrentController;
  late TextEditingController _quantityTotalController;
  late TextEditingController _batchNumberController;
  late TextEditingController _manufacturerController;
  late TextEditingController _lowStockThresholdController;
  late TextEditingController _doseAmountController;

  String _dosageForm = 'tablet';
  DateTime? _expiryDate;
  List<String> _doseTimes = ['08:00', '20:00'];
  List<int> _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
  String? _selectedFamilyMemberId;
  bool _isSaving = false;
  bool _isOcrScanning = false;

  final List<String> _dosageForms = [
    'tablet',
    'syrup',
    'injection',
    'drops',
    'inhaler',
    'capsule',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _genericNameController = TextEditingController(
      text: med?.genericName ?? '',
    );
    _strengthController = TextEditingController(text: med?.strength ?? '');
    _quantityCurrentController = TextEditingController(
      text: med?.quantityCurrent.toString() ?? '5',
    );
    _quantityTotalController = TextEditingController(
      text: med?.quantityTotal.toString() ?? '10',
    );
    _batchNumberController = TextEditingController(
      text: med?.batchNumber ?? '',
    );
    _manufacturerController = TextEditingController(
      text: med?.manufacturer ?? '',
    );
    _lowStockThresholdController = TextEditingController(
      text: med?.lowStockThreshold.toString() ?? '5',
    );
    _doseAmountController = TextEditingController(
      text: med?.schedule.doseAmount.toString() ?? '1',
    );

    if (med != null) {
      _dosageForm = med.dosageForm ?? 'tablet';
      _expiryDate = med.expiryDate;
      _doseTimes = List.from(med.schedule.doseTimes);
      _daysOfWeek = List.from(med.schedule.daysOfWeek);
      _selectedFamilyMemberId = med.familyMemberId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _strengthController.dispose();
    _quantityCurrentController.dispose();
    _quantityTotalController.dispose();
    _batchNumberController.dispose();
    _manufacturerController.dispose();
    _lowStockThresholdController.dispose();
    _doseAmountController.dispose();
    super.dispose();
  }

  void _dictateIntoController(TextEditingController controller) {
    _voiceHelper.startListening(
      onResult: (words) {
        setState(() {
          controller.text = words;
        });
      },
      onError: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.warning),
        );
      },
    );
  }

  void _showDescribeWithAiModal() {
    final textController = TextEditingController();
    bool isProcessing = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.85,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Column(
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
            Flexible(
              fit: FlexFit.loose,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text('Describe with AI', style: AppTypography.headingMedium),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Type or dictate a description (e.g. "Napa 500mg, 1 tablet twice daily, 10 tablets"). Gemini AI will auto-populate the form.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 2,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'e.g. Napa 500mg, 2 times daily for 10 days',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primaryBlue),
                    onPressed: () {
                      _voiceHelper.startListening(
                        onResult: (words) {
                          setModalState(() {
                            textController.text = words;
                          });
                        },
                        onError: (err) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: AppColors.warning),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SoftPrimaryButton(
                label: 'Fill Form with AI',
                isLoading: isProcessing,
                onPressed: isProcessing
                    ? null
                    : () async {
                        final prompt = textController.text.trim();
                        if (prompt.isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        setModalState(() => isProcessing = true);
                        try {
                          final gemini = GeminiAiService();
                          final response = await gemini.sendMessage(
                            history: [],
                            userPrompt:
                                'User wants to add medication: $prompt. Provide ADD_MEDICINE action JSON block.',
                          );

                          if (response.action != null &&
                              response.action!.type == GeminiActionType.addMedicine) {
                            final data = response.action!.data;
                            final name = data['name'] as String?;
                            final dosage = data['dosage'] as String?;
                            final stock = data['stock'];

                            setState(() {
                              if (name != null && name.isNotEmpty && _nameController.text.isEmpty) {
                                _nameController.text = name;
                              }
                              if (dosage != null && dosage.isNotEmpty && _strengthController.text.isEmpty) {
                                _strengthController.text = dosage;
                              }
                              if (stock != null && _quantityCurrentController.text.isEmpty) {
                                _quantityCurrentController.text = '$stock';
                                _quantityTotalController.text = '$stock';
                              }
                            });

                            if (mounted) {
                              nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Form populated! Please review and tap Save.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Could not extract medication info from description.'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('AI fill failed: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        } finally {
                          setModalState(() => isProcessing = false);
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
  }

  Future<void> _scanBoxPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _isOcrScanning = true);
    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      _applyOcrResult(recognizedText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OCR Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isOcrScanning = false);
    }
  }

  void _applyOcrResult(RecognizedText recognizedText) {
    final lines = recognizedText.blocks
        .expand((b) => b.lines)
        .map(
          (l) => OcrTextLine(
            text: l.text,
            boundingBoxHeight: l.boundingBox.height.toDouble(),
          ),
        )
        .toList();
    final parsedData = MedicineBoxOcrParser.parse(lines);

    setState(() {
      if (_expiryDate == null && parsedData.expiryDate != null) {
        _expiryDate = parsedData.expiryDate;
      }
      if (_batchNumberController.text.isEmpty && parsedData.batchNumber != null) {
        _batchNumberController.text = parsedData.batchNumber!;
      }
      if (_nameController.text.isEmpty && parsedData.nameCandidate != null) {
        _nameController.text = parsedData.nameCandidate!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Box scanned! Auto-filled fields from OCR.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doseTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one dose time'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final schedule = MedicineSchedule(
        doseAmount: int.tryParse(_doseAmountController.text) ?? 1,
        timesPerDay: _doseTimes.length,
        doseTimes: _doseTimes,
        daysOfWeek: _daysOfWeek,
        startDate: widget.medicine?.schedule.startDate ?? DateTime.now(),
        endDate: widget.medicine?.schedule.endDate,
        active: widget.medicine?.schedule.active ?? true,
      );

      final isEdit = widget.medicine != null;
      final med = Medicine(
        id: isEdit ? widget.medicine!.id : '',
        name: _nameController.text.trim(),
        genericName: _genericNameController.text.trim().isEmpty
            ? null
            : _genericNameController.text.trim(),
        dosageForm: _dosageForm,
        strength: _strengthController.text.trim().isEmpty
            ? null
            : _strengthController.text.trim(),
        quantityCurrent: int.tryParse(_quantityCurrentController.text) ?? 0,
        quantityTotal: int.tryParse(_quantityTotalController.text) ?? 0,
        expiryDate: _expiryDate,
        batchNumber: _batchNumberController.text.trim().isEmpty
            ? null
            : _batchNumberController.text.trim(),
        manufacturer: _manufacturerController.text.trim().isEmpty
            ? null
            : _manufacturerController.text.trim(),
        imageUrl: widget.medicine?.imageUrl,
        prescriptionId: widget.medicine?.prescriptionId,
        lowStockThreshold:
            int.tryParse(_lowStockThresholdController.text) ?? 5,
        familyMemberId: _selectedFamilyMemberId,
        schedule: schedule,
        createdAt: isEdit ? widget.medicine!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final savedMedicine = await _medicineService.saveMedicine(med);

      try {
        await _notificationService.scheduleMedicineNotifications(savedMedicine);
      } catch (notifErr) {
        debugPrint('Notification scheduling notice: $notifErr');
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save medicine: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
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
            padding: const EdgeInsets.only(right: 8.0),
            child: SoftIconButton(
              icon: Icons.auto_awesome,
              iconColor: AppColors.primaryBlue,
              size: 40,
              tooltip: 'Describe with AI',
              onPressed: _showDescribeWithAiModal,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SoftIconButton(
              icon: _isOcrScanning ? Icons.hourglass_top : Icons.center_focus_strong,
              iconColor: AppColors.primaryBlue,
              size: 40,
              tooltip: 'Scan Medicine Box',
              onPressed: _isOcrScanning ? null : _scanBoxPhoto,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Family Member Assignment
              _buildFamilyMemberSelector(isDark),
              const SizedBox(height: 18),

              // Medicine Information Section
              const SectionHeader(
                title: 'Medicine Information',
                subtitle: 'Essential pharmaceutical & inventory details',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    SoftTextField(
                      controller: _nameController,
                      labelText: 'Medicine Name *',
                      hintText: 'e.g. Napa Extra',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.mic, color: AppColors.primaryBlue),
                        tooltip: 'Speak name',
                        onPressed: () => _dictateIntoController(_nameController),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please enter medicine name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    SoftTextField(
                      controller: _genericNameController,
                      labelText: 'Generic Name',
                      hintText: 'e.g. Paracetamol + Caffeine',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form',
                                style: AppTypography.headingSmall.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _dosageForm,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: _dosageForms
                                    .map(
                                      (f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(
                                          f.toUpperCase(),
                                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _dosageForm = val ?? 'tablet'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SoftTextField(
                            controller: _strengthController,
                            labelText: 'Strength',
                            hintText: 'e.g. 500 mg',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.mic, color: AppColors.primaryBlue),
                              tooltip: 'Speak strength',
                              onPressed: () => _dictateIntoController(_strengthController),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SoftTextField(
                            controller: _quantityCurrentController,
                            labelText: 'Current Stock',
                            hintText: '5',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SoftTextField(
                            controller: _quantityTotalController,
                            labelText: 'Pack Size (Total)',
                            hintText: '10',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Expiry Date', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _expiryDate != null
                            ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                            : 'Not set',
                        style: AppTypography.caption,
                      ),
                      trailing: SoftIconButton(
                        icon: Icons.calendar_today_rounded,
                        iconColor: AppColors.primaryBlue,
                        size: 38,
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expiryDate ??
                                DateTime.now().add(const Duration(days: 180)),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() => _expiryDate = picked);
                          }
                        },
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SoftTextField(
                            controller: _batchNumberController,
                            labelText: 'Batch No.',
                            hintText: 'Optional',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SoftTextField(
                            controller: _manufacturerController,
                            labelText: 'Manufacturer',
                            hintText: 'e.g. Beximco, Square',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SoftTextField(
                      controller: _lowStockThresholdController,
                      labelText: 'Low Stock Alert Threshold',
                      hintText: '5',
                      helperText: 'Alert when remaining stock drops to or below this count',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Schedule Section
              const SectionHeader(
                title: 'Dose Schedule',
                subtitle: 'Configure daily intake times and quantities',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftTextField(
                      controller: _doseAmountController,
                      labelText: 'Dose Amount',
                      hintText: '1',
                      helperText: 'Units per intake (e.g. 1 tablet, 5 ml)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dose Times (${_doseTimes.length} per day)',
                          style: AppTypography.headingSmall.copyWith(fontSize: 14),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_alarm_rounded, size: 18, color: AppColors.primaryBlue),
                          label: Text('Add Time', style: AppTypography.bodySmall.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              final formatted =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              if (!_doseTimes.contains(formatted)) {
                                setState(() {
                                  _doseTimes.add(formatted);
                                  _doseTimes.sort();
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _doseTimes.map((time) {
                        return Chip(
                          label: Text(TimeFormatter.format24To12Hour(time)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: _doseTimes.length > 1
                              ? () => setState(() => _doseTimes.remove(time))
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Action Button
              SoftPrimaryButton(
                label: isEdit ? 'Update Medicine' : 'Save Medicine to Schedule',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveMedicine,
              ),
              const SizedBox(height: 24),
            ],
          ),
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

        return SoftSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign to Family Member (Optional)',
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
          ),
        );
      },
    );
  }
}
