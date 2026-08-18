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
    Color bg;
    Color fg;

    switch (type) {
      case PillType.primary:
        bg = AppColors.primaryBlueLight;
        fg = AppColors.primaryBlue;
        break;
      case PillType.success:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case PillType.warning:
        bg = AppColors.accentOrangeLight;
        fg = const Color(0xFFD97706); // Darker amber for contrast
        break;
      case PillType.danger:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        break;
      case PillType.pink:
        bg = AppColors.accentPinkLight;
        fg = AppColors.accentPink;
        break;
      case PillType.neutral:
        bg = AppColors.divider.withValues(alpha: 0.5);
        fg = AppColors.textSecondary;
        break;
    }

    if (customBgColor != null) bg = customBgColor!;
    if (customTextColor != null) fg = customTextColor!;

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.8),
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
