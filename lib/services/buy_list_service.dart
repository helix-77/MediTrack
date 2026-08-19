import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';

class BuyListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User _authenticatedUser() => requireAuthenticatedUser(_auth);

  // Stream all buy list items for the current user
  Stream<List<BuyListItem>> streamBuyList() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<BuyListItem>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('buyList')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => BuyListItem.fromSnapshot(doc))
                .toList(),
          );
    });
  }

  // Add or update item on buy list
  Future<void> saveBuyItem(BuyListItem item) async {
    final user = _authenticatedUser();

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('buyList');
    final docRef = item.id.isEmpty ? ref.doc() : ref.doc(item.id);
    await docRef.set(item.toMap(), SetOptions(merge: true));
  }

  // Auto-add or update low stock medicine item in buy list
  Future<void> addOrUpdateLowStockItem(Medicine medicine, {int quantityToBuy = 1}) async {
    final user = _authenticatedUser();
    final collection = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('buyList');

    // Check if an unpurchased item already exists for this medicine
    final query = await collection
        .where('medicineId', isEqualTo: medicine.id)
        .where('isPurchased', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      final docRef = collection.doc();
      final item = BuyListItem(
        id: docRef.id,
        medicineId: medicine.id,
        name: medicine.name,
        quantityToBuy: quantityToBuy,
        isPurchased: false,
        isAutoLowStock: true,
        currentStockAtAdd: medicine.quantityCurrent,
        dosageForm: medicine.dosageForm,
        notes: 'Low stock refill (${medicine.quantityCurrent} ${medicine.dosageForm ?? "units"} left)',
        createdAt: DateTime.now(),
      );
      await docRef.set(item.toMap());
    }
  }

  // Sync a list of low stock medicines to the buy list
  Future<void> syncLowStockMedicines(List<Medicine> lowStockMedicines) async {
    for (final med in lowStockMedicines) {
      await addOrUpdateLowStockItem(med);
    }
  }

  // Toggle purchased state and auto-replenish stock if linked to a medicine
  Future<void> togglePurchased(
    BuyListItem item,
    bool isPurchased, {
    int? refillAmount,
  }) async {
    final user = _authenticatedUser();

    final batch = _firestore.batch();
    final itemRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('buyList')
        .doc(item.id);

    batch.update(itemRef, {'isPurchased': isPurchased});

    // If marked as purchased & linked to a medicine, increment stock in medicines collection
    if (isPurchased && item.medicineId != null && item.medicineId!.isNotEmpty) {
      final amountToAdd =
          refillAmount ??
          (item.quantityToBuy > 0 ? item.quantityToBuy * 30 : 30);
      final medRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .doc(item.medicineId);
      batch.update(medRef, {
        'quantityCurrent': FieldValue.increment(amountToAdd),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
  }

  // Clear all purchased items
  Future<void> clearPurchasedItems() async {
    final user = _authenticatedUser();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('buyList')
        .where('isPurchased', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Delete buy list item
  Future<void> deleteBuyItem(String itemId) async {
    final user = _authenticatedUser();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('buyList')
        .doc(itemId)
        .delete();
  }
}
