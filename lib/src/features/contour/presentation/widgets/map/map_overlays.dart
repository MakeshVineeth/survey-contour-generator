import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/js_number.dart';
import '../../controllers/draw_controller.dart';
import '../../controllers/map_view_controller.dart';
import '../../painters/viz_style.dart';

const Color _panelColor = AppColors.overlayPanel;

/// Frosted panel (`backdrop-filter: blur(8px)`) with a rounded border.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.color,
    required this.borderColor,
    required this.radius,
    required this.padding,
    required this.child,
  });

  final Color color;
  final Color borderColor;
  final double radius;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// `.mode-indicator`: shown while drawing a breakline.
class DrawModeIndicator extends StatelessWidget {
  const DrawModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<DrawController, MobileDrawMode>(
      (d) => d.mobileDrawMode,
    );
    final count = context.select<DrawController, int>(
      (d) => d.currentBreakline.length,
    );
    final text = mode == MobileDrawMode.add
        ? '✏️ Click to add points ($count)'
        : '🧭 Pan/Zoom mode - switch to Add Point to continue';
    return _Panel(
      color: AppColors.accentOrange.withValues(alpha: 0.9),
      borderColor: AppColors.accentOrange,
      radius: 6,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        text,
        style: VizStyle.sans(
          12,
          const Color(0xFFFFFFFF),
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// `.coords-display`: world coordinates under the pointer.
class CoordsDisplay extends StatelessWidget {
  const CoordsDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final view = context.read<MapViewController>();
    return ValueListenableBuilder<MapCoords?>(
      valueListenable: view.mouseCoords,
      builder: (context, coords, _) {
        if (coords == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _panelColor,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'X: ${coords.x.toFixed(2)} | Y: ${coords.y.toFixed(2)}',
            style: VizStyle.mono(11, AppColors.textSecondary),
          ),
        );
      },
    );
  }
}

/// `.legend`: point and line colours.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: _panelColor,
      borderColor: AppColors.border,
      radius: 8,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Legend',
              style: VizStyle.sans(
                11,
                AppColors.textSecondary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const _LegendItem(
            color: AppColors.accentCyan,
            dot: true,
            text: 'Points',
          ),
          const _LegendItem(color: AppColors.accentOrange, text: 'Breaklines'),
          const _LegendItem(color: AppColors.accentGreen, text: 'Minor'),
          const _LegendItem(
            color: AppColors.accentRed,
            text: 'Major',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.text,
    this.dot = false,
    this.last = false,
  });

  final Color color;
  final String text;
  final bool dot;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot ? 8 : 16,
            height: dot ? 8 : 3,
            decoration: BoxDecoration(
              color: color,
              shape: dot ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: dot ? null : BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: VizStyle.sans(11, AppColors.textPrimary)),
        ],
      ),
    );
  }
}
