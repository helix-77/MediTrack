import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/logic/auth_guard.dart';

void main() {
  group('authRouteForState', () {
    test('routes signed-out users to welcome', () {
      expect(
        authRouteForState(hasUser: false, isAnonymous: false),
        AuthRoute.welcome,
      );
    });

    test('routes legacy anonymous users to mandatory upgrade', () {
      expect(
        authRouteForState(hasUser: true, isAnonymous: true),
        AuthRoute.accountUpgrade,
      );
    });

    test('routes unverified registered users to verifyEmail', () {
      expect(
        authRouteForState(
          hasUser: true,
          isAnonymous: false,
          isEmailVerified: false,
        ),
        AuthRoute.verifyEmail,
      );
    });

    test('routes registered and verified users into the app', () {
      expect(
        authRouteForState(
          hasUser: true,
          isAnonymous: false,
          isEmailVerified: true,
        ),
        AuthRoute.app,
      );
    });
  });

  test('typed auth errors provide actionable messages', () {
    expect(
      const UnauthenticatedException().toString(),
      'Authentication is required to continue.',
    );
    expect(
      const AnonymousAccountException().toString(),
      'Please complete account setup to continue.',
    );
  });
}
