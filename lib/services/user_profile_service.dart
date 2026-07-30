import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> _ensureAuthenticated() async {
    User? user = _auth.currentUser;
    if (user == null) {
      try {
        final userCred = await _auth.signInAnonymously();
        user = userCred.user;
      } catch (_) {}
    }
    return user;
  }

  // Stream current user profile
  Stream<UserProfile?> streamProfile() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('main')
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          return UserProfile(
            uid: user.uid,
            displayName: user.displayName ?? (user.isAnonymous ? 'Guest User' : 'User'),
            email: user.email ?? '',
          );
        }
        return UserProfile.fromSnapshot(snapshot);
      });
    });
  }

  // Save or update profile data
  Future<void> saveProfile(UserProfile profile) async {
    final user = await _ensureAuthenticated();
    if (user == null) throw Exception("User not authenticated");

    final docRef = _firestore.collection('users').doc(user.uid).collection('profile').doc('main');
    await docRef.set(profile.toMap(), SetOptions(merge: true));

    // Also update Firebase Auth display name if changed
    if (profile.displayName.isNotEmpty && profile.displayName != user.displayName) {
      await user.updateDisplayName(profile.displayName);
    }
  }

  // Update only bdMobile field
  Future<void> updateBdMobile(String bdMobile) async {
    final user = await _ensureAuthenticated();
    if (user == null) throw Exception("User not authenticated");

    final docRef = _firestore.collection('users').doc(user.uid).collection('profile').doc('main');
    await docRef.set({'bdMobile': bdMobile}, SetOptions(merge: true));
  }
}
