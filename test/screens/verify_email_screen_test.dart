import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/screens/verify_email_screen.dart';
import 'package:meditrack/services/auth_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.isVerifiedOnReload = false});

  final bool isVerifiedOnReload;

  @override
  User? get currentUser => null;

  bool reloadCalled = false;
  bool sendVerificationCalled = false;
  bool signOutCalled = false;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Stream<User?> get userChanges => const Stream.empty();

  @override
  Future<bool> reloadUser() async {
    reloadCalled = true;
    return isVerifiedOnReload;
  }

  @override
  Future<void> sendEmailVerification() async {
    sendVerificationCalled = true;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  bool get isPasswordAccount => false;

  @override
  bool get isGoogleAccount => false;

  @override
  Future<void> deleteAccount({String? password}) async {}

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential?> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkAnonymousWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential?> linkAnonymousWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('verify email screen renders verification instructions and controls',
      (tester) async {
    final fakeAuth = _FakeAuthService();

    await tester.pumpWidget(
      Provider<AuthService>.value(
        value: fakeAuth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const VerifyEmailScreen(),
        ),
      ),
    );

    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.text('Check Inbox & Spam Folder'), findsOneWidget);
    expect(find.text('Click the Link & Pull Down'), findsOneWidget);
    expect(find.text("I've Verified My Email"), findsOneWidget);
    expect(find.text('Resend Verification Email'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('tapping check status calls reloadUser on AuthService',
      (tester) async {
    final fakeAuth = _FakeAuthService(isVerifiedOnReload: false);

    await tester.pumpWidget(
      Provider<AuthService>.value(
        value: fakeAuth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const VerifyEmailScreen(),
        ),
      ),
    );

    final checkButton = find.text("I've Verified My Email");
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pump();

    expect(fakeAuth.reloadCalled, isTrue);
    expect(find.textContaining('Email not verified yet'), findsOneWidget);
  });

  testWidgets('tapping resend verification triggers sendEmailVerification and cooldown timer',
      (tester) async {
    final fakeAuth = _FakeAuthService();

    await tester.pumpWidget(
      Provider<AuthService>.value(
        value: fakeAuth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const VerifyEmailScreen(),
        ),
      ),
    );

    final resendButton = find.text('Resend Verification Email');
    await tester.ensureVisible(resendButton);
    await tester.tap(resendButton);
    await tester.pump();

    expect(fakeAuth.sendVerificationCalled, isTrue);
    expect(find.textContaining('Resend Email in 30s'), findsOneWidget);
  });

  testWidgets('pull down refresh triggers checkVerification', (tester) async {
    final fakeAuth = _FakeAuthService(isVerifiedOnReload: true);

    await tester.pumpWidget(
      Provider<AuthService>.value(
        value: fakeAuth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const VerifyEmailScreen(),
        ),
      ),
    );

    // Pull down to trigger RefreshIndicator
    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // Wait for refresh indicator animation

    expect(fakeAuth.reloadCalled, isTrue);
  });
}
