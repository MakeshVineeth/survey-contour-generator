import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../controllers/contour_controller.dart';
import '../../controllers/display_settings_controller.dart';
import '../../controllers/draw_controller.dart';
import '../../controllers/map_view_controller.dart';
import '../../painters/map_geometry.dart';
import '../../painters/map_painter.dart';
import 'map_gestures.dart';
import 'map_overlays.dart';
import 'map_toolbar.dart';

/// The whole right-hand canvas area of the reference: `.canvas-area` with the
/// toolbar, map canvas, gestures, legend, coordinates and draw indicator.
class MapCanvasArea extends StatelessWidget {
  const MapCanvasArea({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MapToolbar(),
        Expanded(child: _MapSurface()),
      ],
    );
  }
}

class _MapSurface extends StatefulWidget {
  const _MapSurface();

  @override
  State<_MapSurface> createState() => _MapSurfaceState();
}

class _MapSurfaceState extends State<_MapSurface> {
  MapGeometry? _geometry;
  MapGestureHandler? _gestures;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _geometry?.dispose();
    super.dispose();
  }

  // ---- Space = temporary pan mode while drawing (lines 1958–1984) -----------

  bool _onKey(KeyEvent event) {
    if (!mounted || event.logicalKey != LogicalKeyboardKey.space) return false;
    final draw = context.read<DrawController>();
    final view = context.read<MapViewController>();
    if (event is KeyUpEvent) {
      final was = view.spacePressed;
      view.setSpacePressed(false);
      draw.setMobileDrawMode(MobileDrawMode.add);
      return was;
    }
    if (!draw.drawMode || _typingInTextField()) return false;
    if (!view.spacePressed) {
      view.setSpacePressed(true);
      draw.setMobileDrawMode(MobileDrawMode.navigate);
    }
    return true;
  }

  bool _typingInTextField() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
  }

  // ---- geometry cache ---------------------------------------------------------

  MapGeometry _geometryFor(ContourController c) {
    final model = c.model;
    final current = _geometry;
    if (current != null &&
        current.matches(
          c.points,
          c.breakLines,
          model.triangles,
          model.contours,
        )) {
      return current;
    }
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    return _geometry = MapGeometry.build(
      points: c.points,
      breakLines: c.breakLines,
      triangles: model.triangles,
      contours: model.contours,
    );
  }

  void _syncViewport(Size size) {
    if (size == _lastSize) return;
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MapViewController>().setViewport(size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = context.read<MapViewController>();
    final draw = context.read<DrawController>();
    _gestures ??= MapGestureHandler(view: view, draw: draw);
    // Rebuild when the data model or its inputs are replaced.
    context.select<ContourController, Object>(
      (c) => (c.points, c.breakLines, c.model),
    );
    final geometry = _geometryFor(context.read<ContourController>());
    final layers = context.select<DisplaySettingsController, MapLayers>(
      (d) => MapLayers(
        tin: d.showTIN,
        contours: d.showContours,
        breakLines: d.showBreakLines,
        labels: d.showLabels,
      ),
    );
    final drawMode = context.select<DrawController, bool>((d) => d.drawMode);
    final hasData = context.select<ContourController, bool>(
      (c) => c.points.isNotEmpty,
    );
    final grab = context.select<MapViewController, bool>((v) => v.spacePressed);
    final adding = context.select<DrawController, bool>(
      (d) => d.drawMode && d.mobileDrawMode == MobileDrawMode.add,
    );

    // The coordinates box changes size on (almost) every pointer move, which
    // re-lays out this LayoutBuilder and marks it for repaint. Without a
    // boundary here that repaint climbs to the route and re-records the
    // header, toolbar and sidebar on every mouse move.
    return ColoredBox(
      color: AppColors.bgPrimary,
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            _syncViewport(size);
            return _buildSurface(
              geometry,
              layers,
              drawMode,
              hasData,
              size,
              view,
              draw,
              grab ? SystemMouseCursors.grab : _addCursor(adding),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSurface(
    MapGeometry geometry,
    MapLayers layers,
    bool drawMode,
    bool hasData,
    Size size,
    MapViewController view,
    DrawController draw,
    MouseCursor cursor,
  ) {
    final gestures = _gestures!;
    return ClipRect(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: gestures.onDown,
        onPointerMove: gestures.onMove,
        onPointerHover: gestures.onHover,
        onPointerUp: gestures.onUp,
        onPointerCancel: gestures.onUp,
        onPointerSignal: gestures.onSignal,
        child: MouseRegion(
          cursor: cursor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MapCanvas(
                view: view,
                geometry: geometry,
                layers: layers,
                drawMode: drawMode,
                draw: draw,
              ),
              if (drawMode)
                Positioned(
                  top: 16,
                  left: 16,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width > 32 ? size.width - 32 : 0,
                    ),
                    child: const DrawModeIndicator(),
                  ),
                ),
              if (hasData)
                const Positioned(top: 16, right: 16, child: CoordsDisplay()),
              if (hasData)
                const Positioned(bottom: 16, right: 16, child: MapLegend()),
            ],
          ),
        ),
      ),
    );
  }

  MouseCursor _addCursor(bool adding) =>
      adding ? SystemMouseCursors.precise : MouseCursor.defer;
}

/// The painted map; repaints on view changes without rebuilding the tree.
class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.view,
    required this.geometry,
    required this.layers,
    required this.drawMode,
    required this.draw,
  });

  final MapViewController view;
  final MapGeometry geometry;
  final MapLayers layers;
  final bool drawMode;
  final DrawController draw;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: Listenable.merge([view, draw]),
        builder: (context, _) => CustomPaint(
          painter: MapPainter(
            geometry: geometry,
            centerX: view.centerX,
            centerY: view.centerY,
            scale: view.scale,
            layers: layers,
            drawMode: drawMode,
            currentBreakline: draw.currentBreakline,
          ),
        ),
      ),
    );
  }
}
