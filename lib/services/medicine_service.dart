import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _medicinesRef {
    return _firestore.collection('users').doc(_uid).collection('medicines');
  }

  CollectionReference<Map<String, dynamic>> get _doseLogsRef {
    return _firestore.collection('users').doc(_uid).collection('doseLogs');
  }

  // Stream all medicines for the current user
  Stream<List<Medicine>> streamMedicines() {
    return _medicinesRef.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Medicine.fromSnapshot(doc)).toList(),
    );
  }

  // Stream today's dose logs
  Stream<List<DoseLog>> streamTodayDoseLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _doseLogsRef
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DoseLog.fromSnapshot(doc)).toList());
  }

  // Stream dose logs for a specific medicine (last 7 days)
  Stream<List<DoseLog>> streamRecentDoseLogs(String medicineId) {
    final start = DateTime.now().subtract(const Duration(days: 7));
    return _doseLogsRef
        .where('medicineId', isEqualTo: medicineId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DoseLog.fromSnapshot(doc)).toList());
  }

  // Add or update medicine document
  Future<void> saveMedicine(Medicine medicine) async {
    final docRef = medicine.id.isEmpty ? _medicinesRef.doc() : _medicinesRef.doc(medicine.id);
    await docRef.set(medicine.toMap(), SetOptions(merge: true));
  }

  // Delete medicine document
  Future<void> deleteMedicine(String medicineId) async {
    await _medicinesRef.doc(medicineId).delete();
  }

  // Mark dose status (taken/skipped/missed)
  Future<void> updateDoseStatus({
    required String logId,
    required String medicineId,
    required String medicineName,
    required DoseStatus status,
    required int doseAmount,
    DateTime? scheduledAt,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final logRef = logId.isEmpty ? _doseLogsRef.doc() : _doseLogsRef.doc(logId);
    batch.set(
      logRef,
      {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt) : Timestamp.fromDate(now),
        'status': status.name,
        'respondedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    // If taken, decrement quantityCurrent
    if (status == DoseStatus.taken) {
      final medRef = _medicinesRef.doc(medicineId);
      batch.update(medRef, {
        'quantityCurrent': FieldValue.increment(-doseAmount),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }

  // Scan and mark past pending doses as missed if > 2 hours overdue
  Future<void> checkAndMarkMissedDoses() async {
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    final overdueLogs = await _doseLogsRef
        .where('status', isEqualTo: DoseStatus.pending.name)
        .where('scheduledAt', isLessThan: Timestamp.fromDate(twoHoursAgo))
        .get();

    if (overdueLogs.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in overdueLogs.docs) {
      batch.update(doc.reference, {
        'status': DoseStatus.missed.name,
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }
}
