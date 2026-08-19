import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';

/// A reusable soft-neumorphic raised surface container.
/// Features subtle diffuse ambient shadows, soft rounded corners, and customizable padding.
class SoftSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const SoftSurface({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.boxShadow,
    this.onTap,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? AppRadii.cardRadius;
    final effectiveBg = color ?? (isDark ? AppColors.darkSurface : AppColors.surface);
    final effectiveShadow = boxShadow ?? (isDark ? AppShadows.darkCard : AppShadows.softCard);
    final effectiveBorderSide = borderColor != null
        ? BorderSide(color: borderColor!, width: borderWidth ?? 0.8)
        : BorderSide.none;

    Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: content,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: effectiveShadow,
      ),
      child: Material(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        shape: RoundedRectangleBorder(
          borderRadius: effectiveRadius,
          side: effectiveBorderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}

/// Specialized soft card wrapper.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.borderRadius,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftSurface(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      color: color,
      onTap: onTap,
      child: child,
    );
  }
}
