import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditrack/services/auth_service.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Stream<User?> idTokenChanges() => const Stream.empty();

  @override
  Stream<User?> userChanges() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService userChanges Stream Tests', () {
    test('userChanges emits initial value and subsequent notifications', () async {
      final fakeAuth = _FakeFirebaseAuth();
      final authService = AuthService(auth: fakeAuth);
      final emittedValues = <dynamic>[];

      final subscription = authService.userChanges.listen((user) {
        emittedValues.add(user);
      });

      // Wait a microtask for initial yield
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Trigger explicit notification
      authService.notifyUserChanged();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emittedValues.length, greaterThanOrEqualTo(2));
      expect(emittedValues.first, isNull);

      await subscription.cancel();
    });
  });
}
