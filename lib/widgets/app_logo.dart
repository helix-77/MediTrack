import 'package:flutter/material.dart';

/// The official MediTrack vector App Logo.
/// Renders the signature bi-color capsule (Emerald Mint & White), ECG pulse line,
/// and gradient squircle background.
class AppLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size = 64,
    this.borderRadius,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? (size * 0.22);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF4F6BFF).withValues(alpha: 0.32),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: CustomPaint(
          size: Size(size, size),
          painter: _AppLogoPainter(),
        ),
      ),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024.0;

    // 1. Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4F6BFF), Color(0xFF78A5FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. ECG Heartbeat Pulse Line
    final ecgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 16 * scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ecgPath = Path()
      ..moveTo(140 * scale, 760 * scale)
      ..lineTo(340 * scale, 760 * scale)
      ..lineTo(390 * scale, 650 * scale)
      ..lineTo(440 * scale, 870 * scale)
      ..lineTo(490 * scale, 700 * scale)
      ..lineTo(540 * scale, 790 * scale)
      ..lineTo(620 * scale, 760 * scale)
      ..lineTo(884 * scale, 760 * scale);

    canvas.drawPath(ecgPath, ecgPaint);

    // 3. Lower Capsule Half (White)
    final lowerPillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final lowerPillPath = Path()
      ..moveTo(441.289 * scale, 441.289 * scale)
      ..lineTo(306.939 * scale, 575.64 * scale)
      ..cubicTo(
        288.185 * scale, 594.393 * scale,
        277.65 * scale, 619.829 * scale,
        277.65 * scale, 646.35 * scale,
      )
      ..cubicTo(
        277.65 * scale, 672.872 * scale,
        288.185 * scale, 698.307 * scale,
        306.939 * scale, 717.061 * scale,
      )
      ..cubicTo(
        325.693 * scale, 735.815 * scale,
        351.128 * scale, 746.35 * scale,
        377.65 * scale, 746.35 * scale,
      )
      ..cubicTo(
        404.171 * scale, 746.35 * scale,
        429.607 * scale, 735.815 * scale,
        448.36 * scale, 717.061 * scale,
      )
      ..lineTo(582.711 * scale, 582.711 * scale)
      ..lineTo(441.289 * scale, 441.289 * scale)
      ..close();

    canvas.drawPath(lowerPillPath, lowerPillPaint);

    // 4. Upper Capsule Half (Emerald Mint #00D68F)
    final upperPillPaint = Paint()
      ..color = const Color(0xFF00D68F)
      ..style = PaintingStyle.fill;

    final upperPillPath = Path()
      ..moveTo(441.289 * scale, 441.289 * scale)
      ..lineTo(575.64 * scale, 306.939 * scale)
      ..cubicTo(
        594.393 * scale, 288.185 * scale,
        619.829 * scale, 277.65 * scale,
        646.35 * scale, 277.65 * scale,
      )
      ..cubicTo(
        672.872 * scale, 277.65 * scale,
        698.307 * scale, 288.185 * scale,
        717.061 * scale, 306.939 * scale,
      )
      ..cubicTo(
        735.815 * scale, 325.693 * scale,
        746.35 * scale, 351.128 * scale,
        746.35 * scale, 377.65 * scale,
      )
      ..cubicTo(
        746.35 * scale, 404.171 * scale,
        735.815 * scale, 429.607 * scale,
        717.061 * scale, 448.36 * scale,
      )
      ..lineTo(582.711 * scale, 582.711 * scale)
      ..lineTo(441.289 * scale, 441.289 * scale)
      ..close();

    canvas.drawPath(upperPillPath, upperPillPaint);

    // 5. Dividing Center Stroke
    final dividerPaint = Paint()
      ..color = const Color(0xFF5B8FF5)
      ..strokeWidth = (6 * scale).clamp(1.0, 6.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(432.804 * scale, 432.804 * scale),
      Offset(591.196 * scale, 591.196 * scale),
      dividerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
