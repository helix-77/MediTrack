import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Standard dynamic modal bottom sheet for MediTrack:
/// - Occupies dynamically based on content size, capped at [maxHeightFactor] (default 85%) of screen height.
/// - Empty / short content naturally wraps (~25-30% height).
/// - Moderate content sizes to fit (~40-55% height).
/// - Large content expands up to 85% and scrolls smoothly with bouncing physics.
/// - Keeps the background above the sheet blurred with a backdrop filter.
/// - Allows gesture dismissals (swiping/dragging down or tapping the blurred backdrop).
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double maxHeightFactor = 0.85,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (modalContext) {
      final screenHeight = MediaQuery.of(modalContext).size.height;
      final maxTargetHeight = screenHeight * maxHeightFactor;

      return Stack(
        children: [
          // Blurred background backdrop over the entire screen area above the sheet
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isDismissible ? () => Navigator.of(modalContext).pop() : null,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: (isDark ? Colors.black : const Color(0xFF0F172A)).withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          // Dynamic height bottom sheet container (capped at maxHeightFactor, default 85%)
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent taps inside the bottom sheet from dismissing it
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxTargetHeight,
                  minWidth: double.infinity,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      child: builder(modalContext),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
