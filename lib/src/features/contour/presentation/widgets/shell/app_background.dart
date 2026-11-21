import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../../core/theme/app_colors.dart';

/// `.app-container` background: two soft elliptical glows over bg-primary.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _BackgroundPainter(), child: child);
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bgPrimary);
    _glow(canvas, size, const Offset(0.2, 0.2), AppColors.accentCyan, 0x0D);
    _glow(canvas, size, const Offset(0.8, 0.8), AppColors.accentOrange, 0x08);
  }

  /// `radial-gradient(ellipse at (fx, fy), rgba(c, a) 0%, transparent 50%)`
  /// (farthest-corner sizing).
  void _glow(Canvas canvas, Size size, Offset f, Color color, int alpha) {
    if (size.isEmpty) return;
    final c = Offset(size.width * f.dx, size.height * f.dy);
    final rx = math.max(c.dx, size.width - c.dx) * math.sqrt2;
    final ry = math.max(c.dy, size.height - c.dy) * math.sqrt2;
    final shader = RadialGradient(
      colors: [color.withAlpha(alpha), color.withAlpha(0)],
      stops: const [0, 0.5],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(rx, ry)
      ..drawRect(
        Rect.fromLTWH(
          -c.dx / rx,
          -c.dy / ry,
          size.width / rx,
          size.height / ry,
        ),
        Paint()..shader = shader,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}
