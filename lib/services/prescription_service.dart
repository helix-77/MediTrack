import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../models/prescription.dart';

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

  // Save prescription document & optional image to Firebase Storage
  Future<void> savePrescription(
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
      createdAt: prescription.createdAt,
    );

    await docRef.set(updated.toMap(), SetOptions(merge: true));
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
