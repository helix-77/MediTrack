import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../models/buy_list_item.dart';

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
