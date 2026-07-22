import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineSchedule {
  final int doseAmount;
  final int timesPerDay;
  final List<String> doseTimes; // e.g. ["08:00", "20:00"]
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  final DateTime startDate;
  final DateTime? endDate;
  final bool active;

  MedicineSchedule({
    required this.doseAmount,
    required this.timesPerDay,
    required this.doseTimes,
    required this.daysOfWeek,
    required this.startDate,
    this.endDate,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'doseAmount': doseAmount,
      'timesPerDay': timesPerDay,
      'doseTimes': doseTimes,
      'daysOfWeek': daysOfWeek,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'active': active,
    };
  }

  factory MedicineSchedule.fromMap(Map<String, dynamic> map) {
    return MedicineSchedule(
      doseAmount: map['doseAmount'] as int? ?? 1,
      timesPerDay: map['timesPerDay'] as int? ?? 1,
      doseTimes: List<String>.from(map['doseTimes'] ?? []),
      daysOfWeek: List<int>.from(map['daysOfWeek'] ?? [1, 2, 3, 4, 5, 6, 7]),
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      active: map['active'] as bool? ?? true,
    );
  }
}
