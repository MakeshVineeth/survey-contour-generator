import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../../domain/entities/geometry.dart';
import 'contour_controller.dart';

/// World position under the pointer (shown by the coordinates display).
typedef MapCoords = ({double x, double y});

/// Pan/zoom state of the map (reference `view`, lines 1669–1760 and
/// 1986–2180). World Y points up; screen Y points down.
class MapViewController extends ChangeNotifier {
  /// Listens to [contours] to fit the first loaded data set and chains
  /// `onDataReset` (the previous callback keeps running).
  MapViewController(this._contours) {
    _hadPoints = _contours.points.isNotEmpty;
    _contours.addListener(_onContoursChanged);
    _previousReset = _contours.onDataReset;
    _contours.onDataReset = _handleDataReset;
  }

  static const double minScale = 0.001;
  static const double maxScale = 10000;
  static const double fitPadding = 80;
  static const double buttonZoomFactor = 1.3;
  static const double wheelZoomOut = 0.85;
  static const double wheelZoomIn = 1.15;

  final ContourController _contours;
  VoidCallback? _previousReset;

  double _centerX = 0;
  double _centerY = 0;
  double _scale = 1;
  Size _viewport = Size.zero;
  bool _hadPoints = false;
  bool _pendingFit = false;
  bool _spacePressed = false;
  bool _disposed = false;

  double _panStartCenterX = 0;
  double _panStartCenterY = 0;

  /// Latest pointer position in world units (null until the pointer moves).
  final ValueNotifier<MapCoords?> mouseCoords = ValueNotifier(null);

  double get centerX => _centerX;
  double get centerY => _centerY;
  double get scale => _scale;
  Size get viewport => _viewport;
  bool get spacePressed => _spacePressed;
  bool get hasData => _contours.points.isNotEmpty;
  bool get hasViewport => _viewport.width > 0 && _viewport.height > 0;

  // ---- coordinate mapping ---------------------------------------------------

  /// Screen position (relative to the canvas) to world coordinates.
  MapCoords screenToWorld(Offset screen) => (
    x: _centerX + (screen.dx - _viewport.width / 2) / _scale,
    y: _centerY - (screen.dy - _viewport.height / 2) / _scale,
  );

  // ---- viewport / fit -------------------------------------------------------

  /// Called with the canvas size. A real resize refits when data is loaded
  /// (the JS `resize` listener); the first size runs any deferred fit.
  void setViewport(Size size) {
    if (size == _viewport) return;
    final previous = _viewport;
    final first = !hasViewport;
    _viewport = size;
    if (!hasViewport) return;
    if (_pendingFit || (!first && hasData && _isWindowResize(previous, size))) {
      fitToData();
    } else {
      _notify();
    }
  }

  /// A change of width, or a large change of height (rotation, window resize),
  /// is a real resize. A small height change is the toolbar above the map
  /// re-wrapping (draw mode, mode buttons, a longer scale label); refitting for
  /// that would reset the user's zoom and pan every time it happens.
  static bool _isWindowResize(Size from, Size to) {
    if ((to.width - from.width).abs() > 1) return true;
    return (to.height - from.height).abs() > from.height * 0.25;
  }

  /// Centres the view on the data bounds with an 80 px margin.
  void fitToData() {
    final points = _contours.points;
    if (points.isEmpty) return;
    if (!hasViewport) {
      _pendingFit = true;
      return;
    }
    _pendingFit = false;
    final b = _bounds(points, _contours.breakLines);
    final dataW = b.maxX - b.minX == 0 ? 1.0 : b.maxX - b.minX;
    final dataH = b.maxY - b.minY == 0 ? 1.0 : b.maxY - b.minY;
    final sx = (_viewport.width - fitPadding * 2) / dataW;
    final sy = (_viewport.height - fitPadding * 2) / dataH;
    final next = math.min(sx, sy);
    if (!next.isFinite) return;
    _centerX = (b.minX + b.maxX) / 2;
    _centerY = (b.minY + b.maxY) / 2;
    _scale = next.clamp(minScale, maxScale);
    _notify();
  }

  static ({double minX, double maxX, double minY, double maxY}) _bounds(
    List<SurveyPoint> points,
    List<BreakLine> breakLines,
  ) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    void add(double x, double y) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    for (final p in points) {
      add(p.x, p.y);
    }
    for (final bl in breakLines) {
      for (final p in bl.points) {
        add(p.x, p.y);
      }
    }
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  // ---- zoom -----------------------------------------------------------------

  /// Toolbar zoom: changes the scale only, keeping the centre.
  void zoomCentered(double factor) {
    if (!hasData || !factor.isFinite || factor <= 0) return;
    _scale = (_scale * factor).clamp(minScale, maxScale);
    _notify();
  }

  /// Zoom about the screen point [at] (wheel and pinch).
  void zoomAt(Offset at, double factor) {
    if (!hasData || !hasViewport || !factor.isFinite || factor <= 0) return;
    final world = screenToWorld(at);
    final next = (_scale * factor).clamp(minScale, maxScale);
    _centerX = world.x - (at.dx - _viewport.width / 2) / next;
    _centerY = world.y + (at.dy - _viewport.height / 2) / next;
    _scale = next;
    _notify();
  }

  /// Mouse wheel: scrolling down zooms out by 0.85, up zooms in by 1.15.
  void wheelZoom(Offset at, double deltaY) =>
      zoomAt(at, deltaY > 0 ? wheelZoomOut : wheelZoomIn);

  // ---- pan ------------------------------------------------------------------

  void beginPan() {
    _panStartCenterX = _centerX;
    _panStartCenterY = _centerY;
  }

  /// Pans by the total pointer movement [delta] since [beginPan].
  void panTo(Offset delta) {
    _centerX = _panStartCenterX - delta.dx / _scale;
    _centerY = _panStartCenterY + delta.dy / _scale;
    _notify();
  }

  // ---- pointer / keys -------------------------------------------------------

  /// Tracks the pointer for the coordinates display (only with data).
  void updateMouse(Offset screen) {
    if (!hasData || !hasViewport) return;
    mouseCoords.value = screenToWorld(screen);
  }

  void setSpacePressed(bool value) {
    if (_spacePressed == value) return;
    _spacePressed = value;
    _notify();
  }

  // ---- data hooks -----------------------------------------------------------

  void _handleDataReset() {
    _previousReset?.call();
    _hadPoints = false;
    _pendingFit = false;
    _centerX = 0;
    _centerY = 0;
    _scale = 1;
    mouseCoords.value = null;
    _notify();
  }

  void _onContoursChanged() {
    final has = hasData;
    if (has && !_hadPoints) {
      _hadPoints = true;
      fitToData();
    } else if (!has) {
      _hadPoints = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _contours.removeListener(_onContoursChanged);
    if (_contours.onDataReset == _handleDataReset) {
      _contours.onDataReset = _previousReset;
    }
    mouseCoords.dispose();
    super.dispose();
  }
}
