import 'package:flutter/foundation.dart';

import '../../../../core/utils/js_number.dart';
import '../../domain/entities/geometry.dart';
import '../../domain/services/draw_elevation.dart';
import 'contour_controller.dart';

/// What a tap does while drawing on touch devices.
enum MobileDrawMode { add, navigate }

/// Breakline drawing state.
class DrawController extends ChangeNotifier {
  DrawController(this._contours);

  final ContourController _contours;

  bool _drawMode = false;
  List<Point3> _currentBreakline = const [];
  MobileDrawMode _mobileDrawMode = MobileDrawMode.add;

  bool get drawMode => _drawMode;
  List<Point3> get currentBreakline => _currentBreakline;
  MobileDrawMode get mobileDrawMode => _mobileDrawMode;

  /// Leaving draw mode with at least two points commits a breakline.
  void toggleDrawMode() {
    if (_drawMode && _currentBreakline.length >= 2) {
      _contours.addBreakLine(_currentBreakline);
      _currentBreakline = const [];
    }
    _drawMode = !_drawMode;
    if (!_drawMode) _currentBreakline = const [];
    _mobileDrawMode = MobileDrawMode.add;
    notifyListeners();
  }

  void cancelDraw() {
    _drawMode = false;
    _currentBreakline = const [];
    _mobileDrawMode = MobileDrawMode.add;
    notifyListeners();
  }

  void undoLastPoint() {
    if (_currentBreakline.isEmpty) return;
    _currentBreakline = List.unmodifiable(
      _currentBreakline.sublist(0, _currentBreakline.length - 1),
    );
    notifyListeners();
  }

  /// Appends [point] to the line being drawn and announces its RL.
  void addPoint(Point3 point) {
    if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) return;
    _currentBreakline = List.unmodifiable([..._currentBreakline, point]);
    notifyListeners();
    _contours.showToast(
      '📍 Point added: RL ${point.z.toFixed(2)}m (extrapolated)',
    );
  }

  /// Adds a point at world position ([x], [y]); RL is interpolated in the TIN
  /// or extrapolated from the survey.
  void addPointAt(double x, double y) {
    final z = DrawElevation.estimate(
      x: x,
      y: y,
      points: _contours.points,
      triangles: _contours.model.triangles,
    );
    addPoint(Point3(x, y, z));
  }

  void setMobileDrawMode(MobileDrawMode mode) {
    if (_mobileDrawMode == mode) return;
    _mobileDrawMode = mode;
    notifyListeners();
  }
}
