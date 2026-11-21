import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../../core/theme/app_colors.dart';

/// The header logo tile: the reference's gradient rounded square with a white
/// hexagon (`⬡`). The hexagon is drawn as a vector so it is exactly centred and
/// independent of font metrics on every platform.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key});

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _HexagonPainter()),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  const _HexagonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 7.0;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      // Pointy-top hexagon, like the `⬡` glyph.
      final angle = -math.pi / 2 + i * math.pi / 3;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = true
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_HexagonPainter oldDelegate) => false;
}
