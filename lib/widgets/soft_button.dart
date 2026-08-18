import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Primary action button styled for the modern soft-neumorphic UI.
class SoftPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SoftPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 50.0,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primaryBlue;
    final fg = foregroundColor ?? Colors.white;

    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadii.standardRadius,
        boxShadow: onPressed == null || isLoading
            ? []
            : [
                BoxShadow(
                  color: bg.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.standardRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: fg,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTypography.buttonText.copyWith(color: fg),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Outlined / Secondary action button.
class SoftSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double? width;
  final Color? borderColor;
  final Color? textColor;

  const SoftSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50.0,
    this.width,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = textColor ?? AppColors.primaryBlue;

    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          side: borderColor != null ? BorderSide(color: borderColor!, width: 1.2) : BorderSide.none,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.standardRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: text),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTypography.buttonText.copyWith(color: text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular or rounded icon button with subtle soft neumorphic elevation.
class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool hasBadge;

  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.tooltip,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppColors.darkSurface : AppColors.surface);
    final color = iconColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    Widget btn = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: AppShadows.subtle,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
          if (hasBadge)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accentPink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    if (onPressed != null) {
      btn = InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size * 0.32),
        child: btn,
      );
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }

    return btn;
  }
}
