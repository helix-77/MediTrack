import 'package:flutter/material.dart';

/// Centralized color system for MediTrack.
/// Follows the soft-neumorphic healthcare palette:
/// Cool pale blue-gray canvas + raised white/pale surfaces + deep navy text + primary blue with pink/orange accents.
class AppColors {
  // Light Canvas & Surfaces
  static const Color canvas = Color(0xFFFCFDFF);
  static const Color background = Color(0xFFFCFDFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Primary Interaction & Brand (Blue)
  static const Color primaryBlue = Color(0xFF5B8FF5);
  static const Color primaryBlueDark = Color(0xFF3B72E8);
  static const Color primaryBlueLight = Color(0xFFEEF4FF);
  static const Color primaryBlueMuted = Color(0xFFD6E4FF);

  // Backward-compatible alias for primary brand color
  static const Color primaryGreen = Color(0xFF5B8FF5);
  static const Color primaryGreenLight = Color(0xFFEEF4FF);

  // Categorical Accents
  static const Color accentPink = Color(0xFFF45BA5);
  static const Color accentPinkLight = Color(0xFFFDF2F7);
  static const Color accentPinkMuted = Color(0xFFFCE7F3);

  static const Color accentOrange = Color(0xFFFFB45F);
  static const Color accentOrangeLight = Color(0xFFFFF8EE);
  static const Color accentOrangeMuted = Color(0xFFFEF3C7);

  // Typography
  static const Color textPrimary = Color(0xFF18233D); // Deep Navy
  static const Color textSecondary = Color(0xFF6B7A90); // Muted Slate
  static const Color textMuted = Color(0xFF94A3B8); // Light Slate
  static const Color textDisabled = Color(0xFFCBD5E1);

  // Borders & Dividers
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Status & Feedback
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // Dark Palette
  static const Color darkCanvas = Color(0xFF121824);
  static const Color darkBackground = Color(0xFF121824);
  static const Color darkSurface = Color(0xFF1C2433);
  static const Color darkSurfaceElevated = Color(0xFF242E40);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkDivider = Color(0xFF283446);
  static const Color darkBorder = Color(0xFF283446);
}
