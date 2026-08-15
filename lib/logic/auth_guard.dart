import 'package:firebase_auth/firebase_auth.dart';

class UnauthenticatedException implements Exception {
  const UnauthenticatedException();

  @override
  String toString() => 'Authentication is required to continue.';
}

class AnonymousAccountException implements Exception {
  const AnonymousAccountException();

  @override
  String toString() => 'Please complete account setup to continue.';
}

User requireAuthenticatedUser(FirebaseAuth auth) {
  final user = auth.currentUser;
  if (user == null) {
    throw const UnauthenticatedException();
  }
  if (user.isAnonymous) {
    throw const AnonymousAccountException();
  }
  return user;
}

enum AuthRoute { welcome, accountUpgrade, app }

AuthRoute authRouteFor(User? user) {
  return authRouteForState(
    hasUser: user != null,
    isAnonymous: user?.isAnonymous ?? false,
  );
}

AuthRoute authRouteForState({
  required bool hasUser,
  required bool isAnonymous,
}) {
  if (!hasUser) return AuthRoute.welcome;
  if (isAnonymous) return AuthRoute.accountUpgrade;
  return AuthRoute.app;
}
