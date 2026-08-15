import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../logic/auth_guard.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

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

      return credential;
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
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

  User _requireAnonymousUser() {
    final user = _auth.currentUser;
    if (user == null) throw const UnauthenticatedException();
    if (!user.isAnonymous) {
      throw StateError('The current account is already registered.');
    }
    return user;
  }

  Future<OAuthCredential?> _googleCredential() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
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
      case 'network-request-failed':
        return 'A network connection is required. Check your connection and try again.';
      default:
        return error.message ??
            'Authentication error occurred (${error.code}).';
    }
  }
}
