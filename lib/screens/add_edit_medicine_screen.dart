import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

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
  bool _isSaving = false;
  bool _isOcrScanning = false;

  final List<String> _dosageForms = ['tablet', 'syrup', 'injection', 'drops', 'inhaler', 'other'];

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _genericNameController = TextEditingController(text: med?.genericName ?? '');
    _strengthController = TextEditingController(text: med?.strength ?? '');
    _quantityCurrentController = TextEditingController(text: med?.quantityCurrent.toString() ?? '30');
    _quantityTotalController = TextEditingController(text: med?.quantityTotal.toString() ?? '30');
    _batchNumberController = TextEditingController(text: med?.batchNumber ?? '');
    _manufacturerController = TextEditingController(text: med?.manufacturer ?? '');
    _lowStockThresholdController = TextEditingController(text: med?.lowStockThreshold.toString() ?? '5');
    _doseAmountController = TextEditingController(text: med?.schedule.doseAmount.toString() ?? '1');

    if (med != null) {
      _dosageForm = med.dosageForm ?? 'tablet';
      _expiryDate = med.expiryDate;
      _doseTimes = List.from(med.schedule.doseTimes);
      _daysOfWeek = List.from(med.schedule.daysOfWeek);
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

  Future<void> _scanBoxPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isOcrScanning = true);

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      _applyOcrHeuristics(recognizedText.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR scanned successfully! Please review pre-filled data.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR scan error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOcrScanning = false);
    }
  }

  void _applyOcrHeuristics(String rawText) {
    final lines = rawText.split('\n');

    // Expiry date pattern
    final expRegex = RegExp(r'(?:exp|expiry|exp date|use before)?\s*(\d{2}[/-]\d{2}[/-]\d{4}|\d{2}[/-]\d{4})', caseSensitive: false);
    final batchRegex = RegExp(r'(?:batch|b\.no|lot)\s*[:.]?\s*([A-Za-z0-9-]+)', caseSensitive: false);

    for (var line in lines) {
      final expMatch = expRegex.firstMatch(line);
      if (expMatch != null && _expiryDate == null) {
        final dateStr = expMatch.group(1);
        if (dateStr != null) {
          try {
            if (dateStr.contains('/')) {
              final parts = dateStr.split('/');
              if (parts.length == 3) {
                _expiryDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              } else if (parts.length == 2) {
                _expiryDate = DateTime(int.parse(parts[1]), int.parse(parts[0]), 1);
              }
            }
          } catch (_) {}
        }
      }

      final batchMatch = batchRegex.firstMatch(line);
      if (batchMatch != null && _batchNumberController.text.isEmpty) {
        _batchNumberController.text = batchMatch.group(1) ?? '';
      }
    }

    if (_nameController.text.isEmpty && lines.isNotEmpty) {
      _nameController.text = lines.first.trim();
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final medId = widget.medicine?.id ?? '';
      final medicine = Medicine(
        id: medId,
        name: _nameController.text.trim(),
        genericName: _genericNameController.text.trim().isEmpty ? null : _genericNameController.text.trim(),
        dosageForm: _dosageForm,
        strength: _strengthController.text.trim().isEmpty ? null : _strengthController.text.trim(),
        quantityCurrent: int.tryParse(_quantityCurrentController.text) ?? 30,
        quantityTotal: int.tryParse(_quantityTotalController.text) ?? 30,
        expiryDate: _expiryDate,
        batchNumber: _batchNumberController.text.trim().isEmpty ? null : _batchNumberController.text.trim(),
        manufacturer: _manufacturerController.text.trim().isEmpty ? null : _manufacturerController.text.trim(),
        lowStockThreshold: int.tryParse(_lowStockThresholdController.text) ?? 5,
        schedule: MedicineSchedule(
          doseAmount: int.tryParse(_doseAmountController.text) ?? 1,
          timesPerDay: _doseTimes.length,
          doseTimes: _doseTimes,
          daysOfWeek: _daysOfWeek,
          startDate: widget.medicine?.schedule.startDate ?? DateTime.now(),
        ),
        createdAt: widget.medicine?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _medicineService.saveMedicine(medicine);
      try {
        await _notificationService.scheduleMedicineNotifications(medicine);
      } catch (notifErr) {
        debugPrint('Notification scheduling notice: $notifErr');
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save medicine: $e')),
        );
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
            icon: _isOcrScanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
              // Medicine Details Section
              Text('Medicine Information', style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name *'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter medicine name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genericNameController,
                decoration: const InputDecoration(labelText: 'Generic Name (e.g. Paracetamol)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dosageForm,
                      decoration: const InputDecoration(labelText: 'Form'),
                      items: _dosageForms
                          .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                          .toList(),
                      onChanged: (val) => setState(() => _dosageForm = val ?? 'tablet'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _strengthController,
                      decoration: const InputDecoration(labelText: 'Strength (e.g. 500 mg)'),
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
                      decoration: const InputDecoration(labelText: 'Current Quantity *'),
                      validator: (val) => val == null || int.tryParse(val) == null ? 'Enter valid number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Low Stock Alert'),
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
                      ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
                      : 'No expiry date set',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
              ),

              const SizedBox(height: 24),
              // Dose Schedule Section
              Text('Dose Schedule', style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _doseAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dose Amount (units per dose)'),
              ),
              const SizedBox(height: 12),
              Text('Dose Times', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._doseTimes.map(
                    (t) => Chip(
                      label: Text(t),
                      onDeleted: () {
                        if (_doseTimes.length > 1) {
                          setState(() => _doseTimes.remove(t));
                        }
                      },
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add Time'),
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 8, minute: 0),
                      );
                      if (time != null) {
                        final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveForm,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Update Medicine' : 'Save Medicine'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
