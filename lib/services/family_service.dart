import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/auth_guard.dart';
import '../models/family_member.dart';

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User _authenticatedUser() => requireAuthenticatedUser(_auth);

  Stream<List<FamilyMember>> streamFamilyMembers() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(<FamilyMember>[]);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('familyMembers')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => FamilyMember.fromSnapshot(doc))
                .toList(),
          );
    });
  }

  Future<void> addFamilyMember(String displayName) async {
    final user = _authenticatedUser();
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return;

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc();

    final member = FamilyMember(
      id: ref.id,
      displayName: trimmed,
      createdAt: DateTime.now(),
    );

    await ref.set(member.toMap());
  }

  Future<void> deleteFamilyMember(String memberId) async {
    final user = _authenticatedUser();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('familyMembers')
        .doc(memberId)
        .delete();
  }
}
