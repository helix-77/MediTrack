import 'package:cloud_firestore/cloud_firestore.dart';

enum DoseStatus { pending, taken, skipped, missed }

class DoseLog {
  final String id;
  final String medicineId;
  final String medicineName;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime? respondedAt;

  DoseLog({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.scheduledAt,
    required this.status,
    this.respondedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status.name,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  factory DoseLog.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr = data['status'] as String? ?? 'pending';
    final statusVal = DoseStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => DoseStatus.pending,
    );

    return DoseLog(
      id: doc.id,
      medicineId: data['medicineId'] as String? ?? '',
      medicineName: data['medicineName'] as String? ?? '',
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: statusVal,
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
