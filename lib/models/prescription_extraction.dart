import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionItem {
  final String id;
  final String extractedName;
  final String? extractedStrength;
  final String? extractedForm;
  final int? extractedFrequencyPerDay;
  final int? extractedDurationDays;
  final String? extractedInstructions;
  final String confidence; // 'high' | 'medium' | 'low'
  final bool confirmed;
  final String? medicineId;

  PrescriptionItem({
    required this.id,
    required this.extractedName,
    this.extractedStrength,
    this.extractedForm,
    this.extractedFrequencyPerDay,
    this.extractedDurationDays,
    this.extractedInstructions,
    this.confidence = 'medium',
    this.confirmed = false,
    this.medicineId,
  });

  PrescriptionItem copyWith({
    String? id,
    String? extractedName,
    String? extractedStrength,
    String? extractedForm,
    int? extractedFrequencyPerDay,
    int? extractedDurationDays,
    String? extractedInstructions,
    String? confidence,
    bool? confirmed,
    String? medicineId,
  }) {
    return PrescriptionItem(
      id: id ?? this.id,
      extractedName: extractedName ?? this.extractedName,
      extractedStrength: extractedStrength ?? this.extractedStrength,
      extractedForm: extractedForm ?? this.extractedForm,
      extractedFrequencyPerDay:
          extractedFrequencyPerDay ?? this.extractedFrequencyPerDay,
      extractedDurationDays:
          extractedDurationDays ?? this.extractedDurationDays,
      extractedInstructions:
          extractedInstructions ?? this.extractedInstructions,
      confidence: confidence ?? this.confidence,
      confirmed: confirmed ?? this.confirmed,
      medicineId: medicineId ?? this.medicineId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'extractedName': extractedName,
      'extractedStrength': extractedStrength,
      'extractedForm': extractedForm,
      'extractedFrequencyPerDay': extractedFrequencyPerDay,
      'extractedDurationDays': extractedDurationDays,
      'extractedInstructions': extractedInstructions,
      'confidence': confidence,
      'confirmed': confirmed,
      'medicineId': medicineId,
    };
  }

  factory PrescriptionItem.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return PrescriptionItem(
      id: snapshot.id,
      extractedName: data['extractedName'] as String? ?? '',
      extractedStrength: data['extractedStrength'] as String?,
      extractedForm: data['extractedForm'] as String?,
      extractedFrequencyPerDay: data['extractedFrequencyPerDay'] as int?,
      extractedDurationDays: data['extractedDurationDays'] as int?,
      extractedInstructions: data['extractedInstructions'] as String?,
      confidence: data['confidence'] as String? ?? 'medium',
      confirmed: data['confirmed'] as bool? ?? false,
      medicineId: data['medicineId'] as String?,
    );
  }

  factory PrescriptionItem.fromJson(Map<String, dynamic> json, {String id = ''}) {
    final name = json['name'] as String? ?? json['extractedName'] as String? ?? '';
    final confidence = (json['confidence'] as String?)?.toLowerCase() ?? 'medium';
    final validConfidence = (confidence == 'high' || confidence == 'medium' || confidence == 'low')
        ? confidence
        : 'medium';

    return PrescriptionItem(
      id: id,
      extractedName: name,
      extractedStrength: json['strength'] as String? ?? json['extractedStrength'] as String?,
      extractedForm: json['form'] as String? ?? json['extractedForm'] as String?,
      extractedFrequencyPerDay: (json['frequency_per_day'] ?? json['extractedFrequencyPerDay']) as int?,
      extractedDurationDays: (json['duration_days'] ?? json['extractedDurationDays']) as int?,
      extractedInstructions: json['instructions'] as String? ?? json['extractedInstructions'] as String?,
      confidence: validConfidence,
      confirmed: validConfidence == 'high',
      medicineId: json['medicineId'] as String?,
    );
  }
}

class PrescriptionDraft {
  final int schemaVersion;
  final String? doctorName;
  final String? patientName;
  final String? date;
  final List<PrescriptionItem> medicines;
  final String? rawText;

  PrescriptionDraft({
    this.schemaVersion = 1,
    this.doctorName,
    this.patientName,
    this.date,
    required this.medicines,
    this.rawText,
  });

  Map<String, dynamic> toMap() {
    return {
      'schema_version': schemaVersion,
      'doctor_name': doctorName,
      'patient_name': patientName,
      'date': date,
      'medicines': medicines.map((m) => m.toMap()).toList(),
      'rawText': rawText,
    };
  }

  factory PrescriptionDraft.fromJson(Map<String, dynamic> json, {String? rawText}) {
    final schemaVersion = json['schema_version'] as int? ?? 1;
    final doctorName = json['doctor_name'] as String?;
    final patientName = json['patient_name'] as String?;
    final date = json['date'] as String?;

    final medList = json['medicines'] as List<dynamic>? ?? [];
    final medicines = medList
        .whereType<Map<String, dynamic>>()
        .map((m) => PrescriptionItem.fromJson(m))
        .toList();

    return PrescriptionDraft(
      schemaVersion: schemaVersion,
      doctorName: doctorName,
      patientName: patientName,
      date: date,
      medicines: medicines,
      rawText: rawText,
    );
  }
}
