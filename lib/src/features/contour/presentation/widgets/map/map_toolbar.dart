import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/js_number.dart';
import '../../controllers/contour_controller.dart';
import '../../controllers/draw_controller.dart';
import '../../controllers/map_view_controller.dart';
import '../../painters/viz_style.dart';

/// `.canvas-toolbar` of the reference (lines 3704–3733).
class MapToolbar extends StatelessWidget {
  const MapToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final drawMode = context.select<DrawController, bool>((d) => d.drawMode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _ZoomGroup(drawMode: drawMode),
          if (drawMode) const _ModeToggle(),
          const _StatusGroup(),
        ],
      ),
    );
  }
}

class _ZoomGroup extends StatelessWidget {
  const _ZoomGroup({required this.drawMode});

  final bool drawMode;

  @override
  Widget build(BuildContext context) {
    final hasPoints = context.select<ContourController, bool>(
      (c) => c.points.isNotEmpty,
    );
    final view = context.read<MapViewController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapToolbarButton(
          label: '＋',
          tooltip: 'Zoom In',
          onPressed: hasPoints
              ? () => view.zoomCentered(MapViewController.buttonZoomFactor)
              : null,
        ),
        const SizedBox(width: 8),
        MapToolbarButton(
          label: '－',
          tooltip: 'Zoom Out',
          onPressed: hasPoints
              ? () => view.zoomCentered(1 / MapViewController.buttonZoomFactor)
              : null,
        ),
        const SizedBox(width: 8),
        MapToolbarButton(
          label: '⛶ Fit',
          tooltip: 'Fit to View',
          onPressed: hasPoints ? view.fitToData : null,
        ),
        if (drawMode)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '● DRAWING',
              style: VizStyle.sans(
                11,
                AppColors.accentOrange,
                weight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusGroup extends StatelessWidget {
  const _StatusGroup();

  @override
  Widget build(BuildContext context) {
    final scale = context.select<MapViewController, double>((v) => v.scale);
    final (tri, contours) = context.select<ContourController, (int, int)>(
      (c) => (c.model.triangles.length, c.model.contours.length),
    );
    final style = VizStyle.sans(11, AppColors.textMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text('Scale: ${scale.toFixed(2)}x', style: style)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            tri > 0 ? '$tri tri | $contours contours' : 'No data',
            style: style,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<DrawController, MobileDrawMode>(
      (d) => d.mobileDrawMode,
    );
    final draw = context.read<DrawController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _ModeButton(
            label: '➕ Add Point',
            active: mode == MobileDrawMode.add,
            onTap: () => draw.setMobileDrawMode(MobileDrawMode.add),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: _ModeButton(
            label: '🧭 Pan/Zoom',
            active: mode == MobileDrawMode.navigate,
            onTap: () => draw.setMobileDrawMode(MobileDrawMode.navigate),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentCyan : AppColors.border;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.accentCyan : AppColors.bgTertiary,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                        blurRadius: 15,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: VizStyle.sans(
                11,
                active ? AppColors.bgPrimary : AppColors.textSecondary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn.btn-sm.btn-secondary`: 12px, 6x10 padding, hover fills with border.
class MapToolbarButton extends StatefulWidget {
  const MapToolbarButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<MapToolbarButton> createState() => _MapToolbarButtonState();
}

class _MapToolbarButtonState extends State<MapToolbarButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: enabled && _hover
                    ? AppColors.border
                    : AppColors.bgTertiary,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.label,
                style: VizStyle.sans(
                  12,
                  AppColors.textPrimary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
