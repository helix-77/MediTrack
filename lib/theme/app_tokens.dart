import 'package:flutter/material.dart';
import 'colors.dart';

/// Spacing scale across MediTrack.
/// Adheres strictly to the 4/8/12/16/20/24/32/40 scale.
class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;

  // Screen Padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 16.0,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(18.0);
  static const EdgeInsets dialogPadding = EdgeInsets.all(24.0);
}

/// Border Radii scale for modern, soft-curved healthcare UI.
class AppRadii {
  static const double small = 12.0; // Chips, badges, small controls
  static const double standard = 16.0; // Buttons, inputs, small cards
  static const double card = 22.0; // Primary surfaces, medicine cards
  static const double large = 28.0; // Large surfaces, bottom sheet modals
  static const double full = 999.0; // Circular, pills, floating action

  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get standardRadius => BorderRadius.circular(standard);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get pillRadius => BorderRadius.circular(full);
}

/// Soft-neumorphic elevation and ambient depth system.
/// Uses diffuse cool-tint ambient shadows and soft upper highlights.
class AppShadows {
  /// Default soft-neumorphic card elevation for raised surfaces.
  static List<BoxShadow> get softCard => [
        BoxShadow(
          color: const Color(0xFF18233D).withValues(alpha: 0.05),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.9),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, -2),
        ),
      ];

  /// Subtle elevation for minor items or chips.
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: const Color(0xFF18233D).withValues(alpha: 0.03),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
      ];

  /// Floating elevation for primary CTAs, FABs, and floating bottom navigation.
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.primaryBlue.withValues(alpha: 0.25),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF18233D).withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  /// Soft dark mode surface shadow.
  static List<BoxShadow> get darkCard => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];
}
