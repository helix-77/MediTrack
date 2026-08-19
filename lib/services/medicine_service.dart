import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../logic/notification_identity.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import 'notification_service.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User _authenticatedUser() => requireAuthenticatedUser(_auth);

  // Stream all medicines for the current user safely
  Stream<List<Medicine>> streamMedicines() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<Medicine>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => Medicine.fromSnapshot(doc)).toList(),
          );
    });
  }

  // Stream today's dose logs safely
  Stream<List<DoseLog>> streamTodayDoseLogs() {
    return streamDateDoseLogs(DateTime.now());
  }

  // Stream dose logs for a specific date safely
  Stream<List<DoseLog>> streamDateDoseLogs(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<DoseLog>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('doseLogs')
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduledAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => DoseLog.fromSnapshot(doc)).toList(),
          );
    });
  }

  // Stream dose logs for a specific medicine (last 7 days) safely
  Stream<List<DoseLog>> streamRecentDoseLogs(String medicineId) {
    final start = DateTime.now().subtract(const Duration(days: 7));
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<DoseLog>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('doseLogs')
          .where('medicineId', isEqualTo: medicineId)
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .orderBy('scheduledAt', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => DoseLog.fromSnapshot(doc)).toList(),
          );
    });
  }

  Future<Medicine> saveMedicine(Medicine medicine) async {
    final user = _authenticatedUser();

    final medicinesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('medicines');
    final docRef = medicine.id.isEmpty
        ? medicinesRef.doc()
        : medicinesRef.doc(medicine.id);
    await docRef.set(medicine.toMap(), SetOptions(merge: true));
    return Medicine(
      id: docRef.id,
      name: medicine.name,
      genericName: medicine.genericName,
      dosageForm: medicine.dosageForm,
      strength: medicine.strength,
      quantityCurrent: medicine.quantityCurrent,
      quantityTotal: medicine.quantityTotal,
      expiryDate: medicine.expiryDate,
      batchNumber: medicine.batchNumber,
      manufacturer: medicine.manufacturer,
      imageUrl: medicine.imageUrl,
      lowStockThreshold: medicine.lowStockThreshold,
      schedule: medicine.schedule,
      createdAt: medicine.createdAt,
      updatedAt: medicine.updatedAt,
    );
  }

  // Delete medicine document
  Future<void> deleteMedicine(String medicineId) async {
    final user = _authenticatedUser();

    final medicinesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('medicines');
    await medicinesRef.doc(medicineId).delete();
    await NotificationService().cancelMedicineNotifications(medicineId);
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
    final user = _authenticatedUser();

    final now = DateTime.now();
    final effectiveScheduledAt = scheduledAt ?? now;
    final batch = _firestore.batch();

    final doseLogsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('doseLogs');
    final medicinesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('medicines');

    final effectiveLogId = logId.isEmpty
        ? doseEventIdFor(
            medicineId: medicineId,
            scheduledAt: effectiveScheduledAt,
          )
        : logId;
    final logRef = doseLogsRef.doc(effectiveLogId);
    final existing = await logRef.get();
    final existingStatus = existing.exists
        ? DoseLog.fromSnapshot(existing).status
        : DoseStatus.pending;

    batch.set(logRef, {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'scheduledAt': Timestamp.fromDate(effectiveScheduledAt),
      'status': status.name,
      'respondedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    if (status == DoseStatus.taken && existingStatus != DoseStatus.taken) {
      final medRef = medicinesRef.doc(medicineId);
      batch.update(medRef, {
        'quantityCurrent': FieldValue.increment(-doseAmount),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();

    if (status == DoseStatus.taken && existingStatus != DoseStatus.taken) {
      final medicineSnapshot = await medicinesRef.doc(medicineId).get();
      if (medicineSnapshot.exists) {
        await NotificationService().scheduleMedicineNotifications(
          Medicine.fromSnapshot(medicineSnapshot),
        );
      }
    }
  }

  // Scan and mark past pending doses as missed if > 2 hours overdue
  Future<void> checkAndMarkMissedDoses() async {
    final user = _authenticatedUser();

    final doseLogsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('doseLogs');
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    final overdueLogs = await doseLogsRef
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
