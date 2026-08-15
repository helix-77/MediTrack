import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/screens/welcome_screen.dart';
import 'package:meditrack/theme/app_theme.dart';

void main() {
  testWidgets('welcome screen requires a registered account', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const WelcomeScreen()),
    );

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I Already Have an Account'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsNothing);
  });
}
