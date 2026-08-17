import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/theme/colors.dart';
import 'package:meditrack/theme/theme_notifier.dart';

void main() {
  group('Theme Tests', () {
    testWidgets('lightTheme has light brightness and valid primary color', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.primaryGreen);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    testWidgets('darkTheme has dark brightness and valid dark background', (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(theme.colorScheme.surface, AppColors.darkSurface);
    });

    test('ThemeNotifier toggles dark mode', () {
      final notifier = ThemeNotifier();
      expect(notifier.themeMode, ThemeMode.light);
      expect(notifier.isDarkMode, isFalse);

      notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.themeMode, ThemeMode.dark);
      expect(notifier.isDarkMode, isTrue);

      notifier.toggleDarkMode(false);
      expect(notifier.themeMode, ThemeMode.light);
    });
  });
}
