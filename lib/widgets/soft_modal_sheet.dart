import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Standard modal bottom sheet for MediTrack:
/// - Occupies at most [heightFactor] (default 70%) of the screen height.
/// - Keeps the background above the sheet blurred with a subtle backdrop filter.
/// - Allows gesture dismissals (swiping/dragging down or tapping the blurred backdrop).
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  double heightFactor = 0.70,
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
      final targetHeight = screenHeight * heightFactor;

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
          // 70% height bottom sheet container
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent taps inside the bottom sheet from dismissing it
              child: Container(
                height: targetHeight,
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
        ],
      );
    },
  );
}
