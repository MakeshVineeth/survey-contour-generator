import 'package:flutter/gestures.dart';

import '../../controllers/draw_controller.dart';
import '../../controllers/map_view_controller.dart';

/// Pointer logic of the canvas wrapper (reference lines 2016–2180).
///
/// - Mouse and stylus: in draw mode a press adds a point immediately (as in the
///   reference); otherwise a drag pans and the wheel zooms about the cursor.
/// - Touch: a drag pans and two fingers pinch-zoom, also while drawing. In draw
///   mode (Add Point) only a short *tap* adds a point, on release, so moving the
///   map never drops stray points.
class MapGestureHandler {
  MapGestureHandler({required this.view, required this.draw});

  /// Movement (logical px) after which a touch stops being a tap.
  static const double tapSlop = 16;

  final MapViewController view;
  final DrawController draw;

  final Map<int, Offset> _pointers = {};
  int? _panPointer;
  Offset _panOrigin = Offset.zero;
  double? _lastPinchDistance;

  /// A touch in Add mode that may still turn out to be a tap.
  int? _tapPointer;
  Offset _tapStart = Offset.zero;

  /// True when taps add breakline points (draw mode, Add selected, no Space).
  bool get addsPoints =>
      draw.drawMode &&
      !view.spacePressed &&
      draw.mobileDrawMode == MobileDrawMode.add;

  void onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    final touch = e.kind == PointerDeviceKind.touch;
    if (addsPoints && !touch) {
      _addPoint(e.localPosition);
      return;
    }
    if (_pointers.length > 1) {
      _tapPointer = null;
      _panPointer = null;
      _lastPinchDistance = null;
    } else if (addsPoints) {
      _tapPointer = e.pointer;
      _tapStart = e.localPosition;
    } else {
      _startPan(e.pointer, e.localPosition);
    }
  }

  void onMove(PointerMoveEvent e) {
    view.updateMouse(e.localPosition);
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _pinch();
      return;
    }
    if (_tapPointer == e.pointer &&
        (e.localPosition - _tapStart).distance > tapSlop) {
      // Moved too far to be a tap: from here on the drag pans the map.
      _tapPointer = null;
      _startPan(e.pointer, e.localPosition);
    }
    if (_panPointer == e.pointer) {
      view.panTo(e.localPosition - _panOrigin);
    }
  }

  void onHover(PointerHoverEvent e) => view.updateMouse(e.localPosition);

  void onUp(PointerEvent e) {
    final wasTap =
        e is PointerUpEvent && _tapPointer == e.pointer && _pointers.length == 1;
    _pointers.remove(e.pointer);
    _lastPinchDistance = null;
    if (_tapPointer == e.pointer) _tapPointer = null;
    if (_panPointer == e.pointer) _panPointer = null;
    if (wasTap && addsPoints) {
      _addPoint(e.localPosition);
      return;
    }
    if (_pointers.length == 1) {
      // The remaining finger carries on panning.
      final entry = _pointers.entries.first;
      _startPan(entry.key, entry.value);
    }
  }

  void onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      view.wheelZoom(e.localPosition, e.scrollDelta.dy);
    }
  }

  void _addPoint(Offset at) {
    final w = view.screenToWorld(at);
    draw.addPointAt(w.x, w.y);
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
