import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> _ensureAuthenticated() async {
    User? user = _auth.currentUser;
    if (user == null) {
      try {
        final userCred = await _auth.signInAnonymously();
        user = userCred.user;
      } catch (e) {
        // Safe catch if auth fails or is unconfigured
      }
    }
    return user;
  }

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
          .map((snapshot) => snapshot.docs.map((doc) => Medicine.fromSnapshot(doc)).toList());
    });
  }

  // Stream today's dose logs safely
  Stream<List<DoseLog>> streamTodayDoseLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<DoseLog>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('doseLogs')
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => DoseLog.fromSnapshot(doc)).toList());
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
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('scheduledAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => DoseLog.fromSnapshot(doc)).toList());
    });
  }

  // Add or update medicine document
  Future<void> saveMedicine(Medicine medicine) async {
    final user = await _ensureAuthenticated();
    if (user == null) throw Exception("User not authenticated");

    final medicinesRef = _firestore.collection('users').doc(user.uid).collection('medicines');
    final docRef = medicine.id.isEmpty ? medicinesRef.doc() : medicinesRef.doc(medicine.id);
    await docRef.set(medicine.toMap(), SetOptions(merge: true));
  }

  // Delete medicine document
  Future<void> deleteMedicine(String medicineId) async {
    final user = await _ensureAuthenticated();
    if (user == null) throw Exception("User not authenticated");

    final medicinesRef = _firestore.collection('users').doc(user.uid).collection('medicines');
    await medicinesRef.doc(medicineId).delete();
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
    final user = await _ensureAuthenticated();
    if (user == null) throw Exception("User not authenticated");

    final now = DateTime.now();
    final batch = _firestore.batch();

    final doseLogsRef = _firestore.collection('users').doc(user.uid).collection('doseLogs');
    final medicinesRef = _firestore.collection('users').doc(user.uid).collection('medicines');

    final logRef = logId.isEmpty ? doseLogsRef.doc() : doseLogsRef.doc(logId);
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
      final medRef = medicinesRef.doc(medicineId);
      batch.update(medRef, {
        'quantityCurrent': FieldValue.increment(-doseAmount),
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }

  // Scan and mark past pending doses as missed if > 2 hours overdue
  Future<void> checkAndMarkMissedDoses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doseLogsRef = _firestore.collection('users').doc(user.uid).collection('doseLogs');
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
