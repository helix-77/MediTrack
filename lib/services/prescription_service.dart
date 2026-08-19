import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../models/prescription.dart';
import '../models/prescription_extraction.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';

class PrescriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User _authenticatedUser() => requireAuthenticatedUser(_auth);

  // Stream all saved prescriptions for current user
  Stream<List<Prescription>> streamPrescriptions() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<Prescription>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('prescriptions')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Prescription.fromSnapshot(doc))
                .toList(),
          );
    });
  }

  // Stream items of a single prescription
  Stream<List<PrescriptionItem>> streamPrescriptionItems(String prescriptionId) {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<PrescriptionItem>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('prescriptions')
          .doc(prescriptionId)
          .collection('items')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => PrescriptionItem.fromSnapshot(doc))
                .toList(),
          );
    });
  }

  // Save prescription document & optional image to Firebase Storage
  Future<Prescription> savePrescription(
    Prescription prescription,
    File? imageFile,
  ) async {
    final user = _authenticatedUser();

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prescriptions');
    final docRef = prescription.id.isEmpty
        ? ref.doc()
        : ref.doc(prescription.id);
    String? imageUrl = prescription.imageUrl;

    if (imageFile != null && imageFile.existsSync()) {
      try {
        final storageRef = _storage.ref().child(
          'users/${user.uid}/prescriptions/${docRef.id}.jpg',
        );
        final uploadTask = await storageRef.putFile(imageFile);
        imageUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        // Fallback to local path string if offline/storage restricted
        imageUrl = imageFile.path;
      }
    }

    final updated = Prescription(
      id: docRef.id,
      title: prescription.title,
      doctorName: prescription.doctorName,
      date: prescription.date,
      imageUrl: imageUrl,
      extractedText: prescription.extractedText,
      notes: prescription.notes,
      status: prescription.status,
      createdAt: prescription.createdAt,
    );

    await docRef.set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  // Save prescription draft together with its extracted line items
  Future<Prescription> savePrescriptionWithItems(
    Prescription prescription,
    List<PrescriptionItem> items,
    File? imageFile,
  ) async {
    final user = _authenticatedUser();
    final savedPrescription = await savePrescription(prescription, imageFile);

    final itemsCollection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prescriptions')
        .doc(savedPrescription.id)
        .collection('items');

    final batch = _firestore.batch();
    for (var item in items) {
      final itemDoc = item.id.isEmpty ? itemsCollection.doc() : itemsCollection.doc(item.id);
      batch.set(itemDoc, item.toMap(), SetOptions(merge: true));
    }
    await batch.commit();

    return savedPrescription;
  }

  // Confirm selected items and persist them as actual Medicines in the user's inventory
  Future<void> confirmAndPersistMedicines({
    required String prescriptionId,
    required List<PrescriptionItem> items,
    String? prescriptionImageUrl,
  }) async {
    final user = _authenticatedUser();
    final medicinesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('medicines');
    final itemsCollection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prescriptions')
        .doc(prescriptionId)
        .collection('items');

    final batch = _firestore.batch();

    for (var item in items) {
      if (!item.confirmed) continue;

      final freq = item.extractedFrequencyPerDay ?? 1;
      final List<String> defaultTimes = freq == 1
          ? ['08:00']
          : freq == 2
              ? ['08:00', '20:00']
              : freq == 3
                  ? ['08:00', '14:00', '20:00']
                  : ['08:00', '12:00', '16:00', '20:00'];

      final schedule = MedicineSchedule(
        doseAmount: 1,
        timesPerDay: freq,
        doseTimes: defaultTimes,
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        startDate: DateTime.now(),
        endDate: item.extractedDurationDays != null
            ? DateTime.now().add(Duration(days: item.extractedDurationDays!))
            : null,
        active: true,
      );

      final medDoc = medicinesRef.doc();
      final totalStock = (item.extractedDurationDays ?? 10) * freq;

      final medicine = Medicine(
        id: medDoc.id,
        name: item.extractedName,
        strength: item.extractedStrength,
        dosageForm: item.extractedForm ?? 'tablet',
        quantityCurrent: totalStock,
        quantityTotal: totalStock,
        lowStockThreshold: 5,
        imageUrl: prescriptionImageUrl,
        prescriptionId: prescriptionId,
        schedule: schedule,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      batch.set(medDoc, medicine.toMap());

      // Update item subcollection doc
      if (item.id.isNotEmpty) {
        final itemRef = itemsCollection.doc(item.id);
        batch.update(itemRef, {
          'confirmed': true,
          'medicineId': medDoc.id,
        });
      }
    }

    // Update prescription status to reviewed
    final presRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prescriptions')
        .doc(prescriptionId);
    batch.update(presRef, {'status': 'reviewed'});

    await batch.commit();
  }

  // Delete prescription from Firestore & Firebase Storage
  Future<void> deletePrescription(String id, String? imageUrl) async {
    final user = _authenticatedUser();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prescriptions')
        .doc(id)
        .delete();

    if (imageUrl != null && imageUrl.startsWith('http')) {
      try {
        final storageRef = _storage.refFromURL(imageUrl);
        await storageRef.delete();
      } catch (_) {}
    }
  }
}
