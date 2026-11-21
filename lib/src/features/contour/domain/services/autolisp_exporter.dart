import '../../../../core/utils/js_number.dart';
import '../entities/contour.dart';
import '../entities/geometry.dart';
import 'cad_text.dart';

/// Builds the AutoLISP import script (`IMPORT-ALL`).
final class AutoLispExporter {
  const AutoLispExporter._();

  /// [generatedAt] is injected so the output is deterministic and testable.
  static String build(
    List<Contour> contours,
    List<BreakLine> breakLines,
    List<SurveyPoint> points, {
    required DateTime generatedAt,
  }) {
    final out = StringBuffer()
      ..write('; ContourGen AutoLISP Import Script\n')
      ..write('; Generated: ${generatedAt.toUtc().toIso8601String()}\n')
      ..write('; Load in AutoCAD: (load "filename.lsp") then run: (IMPORT-ALL)\n\n')
      ..write(_createLayers);

    _writePoints(out, points);
    _writeContours(out, contours);
    _writeBreakLines(out, breakLines);

    out
      ..write('(defun C:IMPORT-ALL ()\n')
      ..write('  (CREATE-LAYERS)\n')
      ..write('  (IMPORT-POINTS)\n')
      ..write('  (IMPORT-CONTOURS)\n')
      ..write('  (IMPORT-BREAKLINES)\n')
      ..write('  (command "._ZOOM" "E")\n')
      ..write('  (princ "\\n\\nImport complete! Use ZOOM EXTENTS if needed.")\n')
      ..write('  (princ)\n')
      ..write(')\n\n')
      ..write('(princ "\\nContourGen LISP loaded. Run IMPORT-ALL to import data.")\n')
      ..write('(princ)\n');
    return out.toString();
  }

  static const String _createLayers = '(defun CREATE-LAYERS ()\n'
      '  (command "._LAYER" "M" "Contours-Minor" "C" "3" "" "")\n'
      '  (command "._LAYER" "M" "Contours-Major" "C" "1" "" "")\n'
      '  (command "._LAYER" "M" "Contour-Labels" "C" "2" "" "")\n'
      '  (command "._LAYER" "M" "Breaklines" "C" "6" "" "")\n'
      '  (command "._LAYER" "M" "Survey-Points" "C" "4" "" "")\n'
      '  (princ "\\nLayers created.")\n'
      ')\n\n';

  static void _writePoints(StringBuffer out, List<SurveyPoint> points) {
    out
      ..write('(defun IMPORT-POINTS ()\n')
      ..write('  (command "._LAYER" "S" "Survey-Points" "")\n');
    for (final pt in points) {
      final label = '${sanitizeCadText(pt.borehole)} RL${pt.z.toFixed(2)}';
      out
        ..write('  (command "._POINT" "${pt.x.toFixed(3)},${pt.y.toFixed(3)},${pt.z.toFixed(3)}")\n')
        ..write('  (command "._TEXT" "${(pt.x + 1).toFixed(3)},${(pt.y + 1).toFixed(3)},${pt.z.toFixed(3)}" "1.5" "0" "$label")\n');
    }
    out
      ..write('  (princ (strcat "\\n" (itoa ${points.length}) " points imported."))\n')
      ..write(')\n\n');
  }

  static void _writeContours(StringBuffer out, List<Contour> contours) {
    out.write('(defun IMPORT-CONTOURS ()\n');
    for (final c in contours) {
      final layer = c.isMajor ? 'Contours-Major' : 'Contours-Minor';
      final z = c.level.toFixed(3);
      out
        ..write('  (command "._LAYER" "S" "$layer" "")\n')
        ..write('  (command "._3DPOLY"');
      for (final p in c.points) {
        out.write(' "${p.x.toFixed(3)},${p.y.toFixed(3)},$z"');
      }
      out.write(' "")\n');

      if (c.points.length >= 2) {
        final mid = c.points[c.points.length ~/ 2];
        out
          ..write('  (command "._LAYER" "S" "Contour-Labels" "")\n')
          ..write('  (command "._TEXT" "${mid.x.toFixed(3)},${mid.y.toFixed(3)},$z" "2.0" "0" "${c.level.toFixed(1)}")\n');
      }
    }
    out
      ..write('  (princ (strcat "\\n" (itoa ${contours.length}) " contours imported."))\n')
      ..write(')\n\n');
  }

  static void _writeBreakLines(StringBuffer out, List<BreakLine> breakLines) {
    out
      ..write('(defun IMPORT-BREAKLINES ()\n')
      ..write('  (command "._LAYER" "S" "Breaklines" "")\n');
    for (final bl in breakLines) {
      out.write('  (command "._3DPOLY"');
      for (final p in bl.points) {
        out.write(' "${p.x.toFixed(3)},${p.y.toFixed(3)},${p.z.toFixed(3)}"');
      }
      out.write(' "")\n');
    }
    out
      ..write('  (princ (strcat "\\n" (itoa ${breakLines.length}) " breaklines imported."))\n')
      ..write(')\n\n');
  }
}
