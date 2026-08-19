import 'dart:async';
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

  final TextEditingController _searchExistingController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Medicine> _existingMedicines = [];
  List<Medicine> _searchResults = [];
  bool _showSearchResults = false;
  StreamSubscription<List<Medicine>>? _medicineSubscription;

  late TextEditingController _nameController;
  late TextEditingController _genericNameController;
  late TextEditingController _quantityCurrentController;
  late TextEditingController _manufacturerController;
  late TextEditingController _doseAmountController;

  DateTime? _expiryDate;
  List<String> _doseTimes = ['08:00', '20:00'];
  List<int> _daysOfWeek = [1, 2, 3, 4, 5, 6, 7];
  String? _selectedFamilyMemberId;
  bool _isSaving = false;
  bool _isOcrScanning = false;

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _genericNameController = TextEditingController(
      text: med?.genericName ?? '',
    );
    _quantityCurrentController = TextEditingController(
      text: med?.quantityCurrent.toString() ?? '10',
    );
    _manufacturerController = TextEditingController(
      text: med?.manufacturer ?? '',
    );
    _doseAmountController = TextEditingController(
      text: med?.schedule.doseAmount.toString() ?? '1',
    );

    if (med != null) {
      _expiryDate = med.expiryDate;
      _doseTimes = List.from(med.schedule.doseTimes);
      _daysOfWeek = List.from(med.schedule.daysOfWeek);
      _selectedFamilyMemberId = med.familyMemberId;
    }

    _medicineSubscription = _medicineService.streamMedicines().listen((meds) {
      if (mounted) {
        setState(() {
          _existingMedicines = meds;
        });
      }
    });

    _searchExistingController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _showSearchResults = _searchFocusNode.hasFocus &&
            _searchExistingController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchExistingController.removeListener(_onSearchChanged);
    _searchExistingController.dispose();
    _searchFocusNode.dispose();
    _medicineSubscription?.cancel();
    _nameController.dispose();
    _genericNameController.dispose();
    _quantityCurrentController.dispose();
    _manufacturerController.dispose();
    _doseAmountController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchExistingController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final filtered = _existingMedicines.where((med) {
      final name = med.name.toLowerCase();
      final generic = med.genericName?.toLowerCase() ?? '';
      return name.contains(query) || generic.contains(query);
    }).toList();

    setState(() {
      _searchResults = filtered;
      _showSearchResults = true;
    });
  }

  void _selectExistingMedicine(Medicine med) {
    _searchFocusNode.unfocus();
    _searchExistingController.clear();
    setState(() {
      _showSearchResults = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditMedicineScreen(medicine: med),
      ),
    );
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
                                final stock = data['stock'];

                                setState(() {
                                  if (name != null && name.isNotEmpty && _nameController.text.isEmpty) {
                                    _nameController.text = name;
                                  }
                                  if (stock != null && _quantityCurrentController.text.isEmpty) {
                                    _quantityCurrentController.text = '$stock';
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
        doseAmount: int.tryParse(_doseAmountController.text.trim()) ?? 1,
        timesPerDay: _doseTimes.length,
        doseTimes: _doseTimes,
        daysOfWeek: _daysOfWeek,
        startDate: widget.medicine?.schedule.startDate ?? DateTime.now(),
        endDate: widget.medicine?.schedule.endDate,
        active: widget.medicine?.schedule.active ?? true,
      );

      final isEdit = widget.medicine != null;
      final currentStock = int.tryParse(_quantityCurrentController.text.trim()) ?? 0;
      final totalStock = widget.medicine != null
          ? (widget.medicine!.quantityTotal < currentStock ? currentStock : widget.medicine!.quantityTotal)
          : currentStock;

      final med = Medicine(
        id: isEdit ? widget.medicine!.id : '',
        name: _nameController.text.trim(),
        genericName: _genericNameController.text.trim().isEmpty
            ? null
            : _genericNameController.text.trim(),
        dosageForm: widget.medicine?.dosageForm ?? 'tablet',
        strength: widget.medicine?.strength,
        quantityCurrent: currentStock,
        quantityTotal: totalStock,
        expiryDate: _expiryDate,
        batchNumber: widget.medicine?.batchNumber,
        manufacturer: _manufacturerController.text.trim().isEmpty
            ? null
            : _manufacturerController.text.trim(),
        imageUrl: widget.medicine?.imageUrl,
        prescriptionId: widget.medicine?.prescriptionId,
        lowStockThreshold: widget.medicine?.lowStockThreshold ?? 3,
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
              // Search Existing Medicine (Add Mode)
              _buildExistingMedicineSearchBar(isDark),

              // ===============================================================
              // SECTION 1: MANDATORY (MUST FILL)
              // ===============================================================
              const SectionHeader(
                title: 'Required Information',
                subtitle: 'Essential medicine & daily schedule details',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftTextField(
                      controller: _nameController,
                      labelText: 'Medicine Name *',
                      hintText: 'e.g. Napa Extra, Seclo 20',
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
                      controller: _quantityCurrentController,
                      labelText: 'Current Stock *',
                      hintText: 'e.g. 10',
                      helperText: 'Number of pills / units available at home',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter current stock';
                        }
                        if (int.tryParse(val.trim()) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    SoftTextField(
                      controller: _doseAmountController,
                      labelText: 'Dose Amount *',
                      hintText: '1',
                      helperText: 'Units per intake (e.g. 1 tablet, 5 ml)',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please enter dose amount'
                          : null,
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
                          label: Text(
                            'Add Time',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

              const SizedBox(height: 24),

              // ===============================================================
              // SECTION 2: OPTIONAL DETAILS (GOOD TO HAVE)
              // ===============================================================
              const SectionHeader(
                title: 'Optional Details',
                subtitle: 'Good-to-have additional information (can be skipped)',
              ),
              SoftSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SoftTextField(
                      controller: _genericNameController,
                      labelText: 'Generic Name',
                      hintText: 'e.g. Paracetamol + Caffeine',
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Expiry Date',
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
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
                    const SizedBox(height: 14),
                    SoftTextField(
                      controller: _manufacturerController,
                      labelText: 'Manufacturer',
                      hintText: 'e.g. Beximco, Square, Incepta',
                    ),
                    const SizedBox(height: 14),
                    _buildFamilyMemberSelector(isDark),
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

  Widget _buildExistingMedicineSearchBar(bool isDark) {
    if (widget.medicine != null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchExistingController,
                  focusNode: _searchFocusNode,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search existing medicine to edit (e.g. Napa)...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_searchExistingController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  onPressed: () {
                    _searchExistingController.clear();
                    _searchFocusNode.unfocus();
                  },
                ),
            ],
          ),
        ),
        if (_showSearchResults) ...[
          const SizedBox(height: 6),
          SoftSurface(
            padding: const EdgeInsets.all(12),
            child: _searchResults.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No existing medicine found matching "${_searchExistingController.text}". Fill the form below to add a new one.',
                            style: AppTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Select to edit existing medication:',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      ..._searchResults.map(
                        (med) => InkWell(
                          onTap: () => _selectExistingMedicine(med),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryBlueLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.medication_rounded,
                                    size: 18,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (med.genericName != null && med.genericName!.isNotEmpty)
                                        Text(
                                          med.genericName!,
                                          style: AppTypography.caption,
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkCanvas : AppColors.canvas,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${med.quantityCurrent} in stock',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: med.quantityCurrent <= 3
                                          ? AppColors.danger
                                          : AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: AppColors.primaryBlue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 18),
      ],
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
