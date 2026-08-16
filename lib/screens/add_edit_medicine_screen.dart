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
      text: med?.quantityCurrent.toString() ?? '30',
    );
    _quantityTotalController = TextEditingController(
      text: med?.quantityTotal.toString() ?? '30',
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text('Describe with AI', style: AppTypography.headingSmall),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Type or dictate a description (e.g. "Napa 500mg, 1 tablet twice daily, 30 tablets"). AI will populate the empty fields.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Napa 500mg, 2 times daily for 10 days',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primaryGreen),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
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
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Fill Form with AI', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
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
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doseTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one dose time')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primaryGreen),
            tooltip: 'Describe with AI',
            onPressed: _showDescribeWithAiModal,
          ),
          IconButton(
            icon: _isOcrScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.center_focus_strong),
            tooltip: 'Scan Medicine Box',
            onPressed: _isOcrScanning ? null : _scanBoxPhoto,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Family Member Assignment
              _buildFamilyMemberSelector(),
              const SizedBox(height: 16),

              // Medicine Details Section
              Text('Medicine Information', style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Medicine Name *',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primaryGreen),
                    tooltip: 'Speak name',
                    onPressed: () => _dictateIntoController(_nameController),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter medicine name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genericNameController,
                decoration: const InputDecoration(
                  labelText: 'Generic Name (e.g. Paracetamol)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dosageForm,
                      decoration: const InputDecoration(labelText: 'Form'),
                      items: _dosageForms
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(f.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _dosageForm = val ?? 'tablet'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _strengthController,
                      decoration: InputDecoration(
                        labelText: 'Strength (e.g. 500 mg)',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.mic, color: AppColors.primaryGreen),
                          tooltip: 'Speak strength',
                          onPressed: () => _dictateIntoController(_strengthController),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCurrentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current Stock',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityTotalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pack Size (Total)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry Date'),
                subtitle: Text(
                  _expiryDate != null
                      ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                      : 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _batchNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Batch Number',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _manufacturerController,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lowStockThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Alert Threshold',
                  helperText: 'Alert when remaining stock is at or below this',
                ),
              ),

              const SizedBox(height: 24),
              // Schedule Section
              Text('Dose Schedule', style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _doseAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dose Amount (e.g. 1 tablet per intake)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dose Times (${_doseTimes.length} per day)'),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Time'),
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
              Wrap(
                spacing: 8,
                children: _doseTimes.map((time) {
                  return Chip(
                    label: Text(TimeFormatter.format24To12Hour(time)),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: _doseTimes.length > 1
                        ? () => setState(() => _doseTimes.remove(time))
                        : null,
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveMedicine,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEdit ? 'Update Medicine' : 'Save Medicine',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyMemberSelector() {
    return StreamBuilder<List<FamilyMember>>(
      stream: _familyService.streamFamilyMembers(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign to Family Member (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Self'),
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
