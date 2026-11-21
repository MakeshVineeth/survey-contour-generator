import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// `.checkbox-group`: 16px cyan-accent checkbox followed by its label.
class CheckboxGroup extends StatelessWidget {
  const CheckboxGroup({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        checked: value,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              CustomPaint(
                size: const Size(16, 16),
                painter: _CheckPainter(value),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppText.ui(12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.checked);

  final bool checked;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      box,
      Paint()..color = checked ? AppColors.accentCyan : const Color(0xFFFFFFFF),
    );
    if (!checked) {
      canvas.drawRRect(
        box.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF767676),
      );
      return;
    }
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.43, size.height * 0.70)
      ..lineTo(size.width * 0.76, size.height * 0.30);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.bgPrimary,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.checked != checked;
}
