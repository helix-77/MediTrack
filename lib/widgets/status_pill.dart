import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

enum PillType {
  primary,
  success,
  warning,
  danger,
  pink,
  neutral,
}

/// A clean, soft-pastel status or category pill badge.
class StatusPill extends StatelessWidget {
  final String label;
  final PillType type;
  final IconData? icon;
  final Color? customBgColor;
  final Color? customTextColor;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.label,
    this.type = PillType.primary,
    this.icon,
    this.customBgColor,
    this.customTextColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;

    switch (type) {
      case PillType.primary:
        bg = isDark ? AppColors.primaryBlue.withValues(alpha: 0.2) : AppColors.primaryBlueLight;
        fg = AppColors.primaryBlue;
        break;
      case PillType.success:
        bg = isDark ? AppColors.success.withValues(alpha: 0.2) : AppColors.successLight;
        fg = AppColors.success;
        break;
      case PillType.warning:
        bg = isDark ? AppColors.warning.withValues(alpha: 0.2) : AppColors.accentOrangeLight;
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        break;
      case PillType.danger:
        bg = isDark ? AppColors.danger.withValues(alpha: 0.2) : AppColors.dangerLight;
        fg = isDark ? const Color(0xFFF87171) : AppColors.danger;
        break;
      case PillType.pink:
        bg = isDark ? AppColors.accentPink.withValues(alpha: 0.2) : AppColors.accentPinkLight;
        fg = AppColors.accentPink;
        break;
      case PillType.neutral:
        bg = isDark ? AppColors.darkSurfaceElevated : AppColors.divider.withValues(alpha: 0.5);
        fg = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
        break;
    }

    if (customBgColor != null) bg = customBgColor!;
    if (customTextColor != null) fg = customTextColor!;

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.pillText.copyWith(color: fg),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillRadius,
        child: pill,
      );
    }

    return pill;
  }
}
