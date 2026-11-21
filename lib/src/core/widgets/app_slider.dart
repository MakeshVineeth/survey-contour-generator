import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// `.slider`: 6px bordered track, 16px gradient thumb with cyan glow.
class AppSlider extends StatelessWidget {
  const AppSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // `.slider-container { padding: 8px 0 }`
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SliderTheme(
        data: const SliderThemeData(
          trackHeight: 6,
          trackShape: _BorderedTrackShape(),
          thumbShape: _GradientThumbShape(),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
          tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 0),
          activeTickMarkColor: Color(0x00000000),
          inactiveTickMarkColor: Color(0x00000000),
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          semanticFormatterCallback: null,
          label: semanticLabel,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BorderedTrackShape extends SliderTrackShape {
  const _BorderedTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 6;
    final top = offset.dy + (parentBox.size.height - h) / 2;
    return Rect.fromLTWH(offset.dx + 8, top, parentBox.size.width - 16, h);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    final canvas = context.canvas;
    canvas.drawRRect(rrect, Paint()..color = AppColors.bgTertiary);
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );
  }
}

class _GradientThumbShape extends SliderComponentShape {
  const _GradientThumbShape();

  static const double _radius = 8;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCircle(center: center, radius: _radius);
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..color = AppColors.accentCyan.withAlpha(0x66)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      _radius,
      Paint()..shader = AppColors.brandGradient.createShader(rect),
    );
    canvas.drawCircle(
      center,
      _radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.bgPrimary,
    );
  }
}
