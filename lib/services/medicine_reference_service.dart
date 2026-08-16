import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../models/medicine_reference.dart';

class MedicineReferenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _ensureAuth() => requireAuthenticatedUser(_auth);

  /// Searches the medicine reference collection by brand name prefix.
  Future<List<MedicineReference>> searchMedicines(
    String query, {
    int limit = 25,
  }) async {
    _ensureAuth();

    final queryLower = MedicineReference.normalizeSearchName(query);
    if (queryLower.length < 2) {
      return [];
    }

    final snapshot = await _firestore
        .collection('medicineReference')
        .where('searchName', isGreaterThanOrEqualTo: queryLower)
        .where('searchName', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => MedicineReference.fromSnapshot(doc))
        .toList();
  }

  /// Finds other brands sharing the same generic name, sorted by price ascending.
  Future<List<MedicineReference>> getAlternativesForGeneric(
    String genericName, {
    String? excludeBrandId,
    int limit = 20,
  }) async {
    _ensureAuth();

    final trimmed = genericName.trim();
    if (trimmed.isEmpty) return [];

    final snapshot = await _firestore
        .collection('medicineReference')
        .where('genericName', isEqualTo: trimmed)
        .limit(limit)
        .get();

    final list = snapshot.docs
        .map((doc) => MedicineReference.fromSnapshot(doc))
        .where((med) => med.id != excludeBrandId)
        .toList();

    // Sort by price ascending (nulls last)
    list.sort((a, b) {
      if (a.unitPriceBdt == null && b.unitPriceBdt == null) return 0;
      if (a.unitPriceBdt == null) return 1;
      if (b.unitPriceBdt == null) return -1;
      return a.unitPriceBdt!.compareTo(b.unitPriceBdt!);
    });

    return list;
  }
}
