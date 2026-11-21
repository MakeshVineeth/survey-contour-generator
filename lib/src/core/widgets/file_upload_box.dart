import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// `.file-upload`: dashed 2px drop-zone style button with icon, text, hint.
class FileUploadBox extends StatefulWidget {
  const FileUploadBox({
    required this.icon,
    required this.text,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String text;
  final String hint;
  final VoidCallback onTap;

  @override
  State<FileUploadBox> createState() => _FileUploadBoxState();
}

class _FileUploadBoxState extends State<FileUploadBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: _hover ? AppColors.accentCyan : AppColors.border,
            fill: _hover
                ? Color.alphaBlend(
                    AppColors.accentCyan.withAlpha(0x0D),
                    AppColors.bgTertiary,
                  )
                : AppColors.bgTertiary,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.icon, style: AppText.ui(32, height: 1.2)),
                  const SizedBox(height: 8),
                  Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: AppText.ui(13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.hint,
                    textAlign: TextAlign.center,
                    style: AppText.ui(11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.fill});

  final Color color;
  final Color fill;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()..addRRect(rrect.deflate(1));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    for (final ui.PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + _dash), stroke);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.fill != fill;
}
