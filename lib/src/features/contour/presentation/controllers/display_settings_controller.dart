import 'package:flutter/foundation.dart';

/// Layer visibility toggles (Layers tab) and the collapsed/expanded
/// borehole list.
class DisplaySettingsController extends ChangeNotifier {
  bool _showTIN = true;
  bool _showContours = true;
  bool _showBreakLines = true;
  bool _showLabels = true;
  bool _showAllBoreholes = false;

  bool get showTIN => _showTIN;
  bool get showContours => _showContours;
  bool get showBreakLines => _showBreakLines;
  bool get showLabels => _showLabels;
  bool get showAllBoreholes => _showAllBoreholes;

  set showTIN(bool value) => _set(_showTIN, value, (v) => _showTIN = v);
  set showContours(bool value) =>
      _set(_showContours, value, (v) => _showContours = v);
  set showBreakLines(bool value) =>
      _set(_showBreakLines, value, (v) => _showBreakLines = v);
  set showLabels(bool value) =>
      _set(_showLabels, value, (v) => _showLabels = v);
  set showAllBoreholes(bool value) =>
      _set(_showAllBoreholes, value, (v) => _showAllBoreholes = v);

  void _set(bool current, bool next, void Function(bool) assign) {
    if (current == next) return;
    assign(next);
    notifyListeners();
  }
}
