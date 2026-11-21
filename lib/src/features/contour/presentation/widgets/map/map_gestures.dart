import 'package:flutter/gestures.dart';

import '../../controllers/draw_controller.dart';
import '../../controllers/map_view_controller.dart';

/// Pointer logic of the canvas wrapper (reference lines 2016–2180): draw-mode
/// taps add points, otherwise a drag pans, two pointers pinch-zoom and the
/// wheel zooms about the cursor.
class MapGestureHandler {
  MapGestureHandler({required this.view, required this.draw});

  final MapViewController view;
  final DrawController draw;

  final Map<int, Offset> _pointers = {};
  int? _panPointer;
  Offset _panOrigin = Offset.zero;
  double? _lastPinchDistance;

  /// True when taps add breakline points (draw mode, Add selected, no Space).
  bool get addsPoints =>
      draw.drawMode &&
      !view.spacePressed &&
      draw.mobileDrawMode == MobileDrawMode.add;

  void onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (addsPoints) {
      final w = view.screenToWorld(e.localPosition);
      draw.addPointAt(w.x, w.y);
      return;
    }
    if (_pointers.length == 1) {
      _startPan(e.pointer, e.localPosition);
    } else {
      _panPointer = null;
      _lastPinchDistance = null;
    }
  }

  void onMove(PointerMoveEvent e) {
    view.updateMouse(e.localPosition);
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _pinch();
    } else if (_panPointer == e.pointer && !addsPoints) {
      view.panTo(e.localPosition - _panOrigin);
    }
  }

  void onHover(PointerHoverEvent e) => view.updateMouse(e.localPosition);

  void onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    _lastPinchDistance = null;
    if (_panPointer == e.pointer) _panPointer = null;
    if (_pointers.length == 1 && !addsPoints) {
      final entry = _pointers.entries.first;
      _startPan(entry.key, entry.value);
    }
  }

  void onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      view.wheelZoom(e.localPosition, e.scrollDelta.dy);
    }
  }

  void _startPan(int pointer, Offset at) {
    _panPointer = pointer;
    _panOrigin = at;
    view.beginPan();
  }

  void _pinch() {
    final a = _pointers.values.first;
    final b = _pointers.values.last;
    final distance = (a - b).distance;
    final last = _lastPinchDistance;
    if (last != null && last > 0) {
      view.zoomAt((a + b) / 2, distance / last);
    }
    _lastPinchDistance = distance;
  }
}
