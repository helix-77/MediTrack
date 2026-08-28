import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../logic/auth_guard.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }

      debugPrint('Triggering sendEmailVerification for ${credential.user?.email}...');
      await credential.user?.sendEmailVerification();
      debugPrint('sendEmailVerification request submitted successfully.');

      return credential;
    } on FirebaseAuthException catch (error) {
      debugPrint('FirebaseAuthException during sign up: ${error.code} - ${error.message}');
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthenticatedException();
    try {
      debugPrint('Sending verification email to: ${user.email}...');
      await user.sendEmailVerification();
      debugPrint('sendEmailVerification request submitted successfully.');
    } on FirebaseAuthException catch (error) {
      debugPrint('FirebaseAuthException during sendEmailVerification: ${error.code} - ${error.message}');
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<bool> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final credential = await _googleCredential();
      if (credential == null) return null;
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    } catch (error) {
      throw Exception('Google Sign-In failed: $error');
    }
  }

  Future<UserCredential> linkAnonymousWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = _requireAnonymousUser();
    try {
      final authCredential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password.trim(),
      );
      final credential = await user.linkWithCredential(authCredential);
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }
      return credential;
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<UserCredential?> linkAnonymousWithGoogle() async {
    final user = _requireAnonymousUser();
    try {
      final credential = await _googleCredential();
      if (credential == null) return null;
      return await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    } catch (error) {
      throw Exception('Google account linking failed: $error');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  bool get isPasswordAccount {
    final user = _auth.currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  bool get isGoogleAccount {
    final user = _auth.currentUser;
    return user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  }

  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthenticatedException();
    try {
      if (password != null && password.trim().isNotEmpty && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password.trim(),
        );
        await user.reauthenticateWithCredential(credential);
      } else if (isGoogleAccount) {
        final credential = await _googleCredential();
        if (credential != null) {
          await user.reauthenticateWithCredential(credential);
        }
      }

      await user.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  User _requireAnonymousUser() {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthenticatedException();
    if (!user.isAnonymous) {
      throw StateError('The current account is already registered.');
    }
    return user;
  }

  Future<OAuthCredential?> _googleCredential() async {
    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      return GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'This credential already belongs to another account. Sign in to that account instead; your current data cannot be merged automatically.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'channel-error':
        return 'Please ensure all email and password fields are filled correctly.';
      case 'requires-recent-login':
        return 'Account deletion requires recent authentication. Please enter your password or log in again.';
      case 'network-request-failed':
        return 'A network connection is required. Check your connection and try again.';
      default:
        return error.message ??
            'Authentication error occurred (${error.code}).';
    }
  }
}
