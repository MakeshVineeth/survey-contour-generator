import '../../../../core/utils/js_number.dart';
import '../entities/contour.dart';
import '../entities/geometry.dart';

/// Builds the Civil 3D / AutoCAD command-line script (`.scr`).
final class Civil3dScriptExporter {
  const Civil3dScriptExporter._();

  static String build(
    List<Contour> contours,
    List<BreakLine> breakLines,
    List<SurveyPoint> points,
  ) {
    final out = StringBuffer()
      ..write('; Civil 3D Script - Run in AutoCAD command line\n')
      ..write('; Copy and paste sections as needed\n\n')
      ..write('; === CREATE LAYERS ===\n')
      ..write('-LAYER M Contours-Minor C 3  \n')
      ..write('-LAYER M Contours-Major C 1  \n')
      ..write('-LAYER M Breaklines C 6  \n')
      ..write('-LAYER M Survey-Points C 4  \n\n')
      ..write('; === SURVEY POINTS ===\n')
      ..write('-LAYER S Survey-Points \n');
    for (final pt in points) {
      out.write('POINT ${pt.x.toFixed(3)},${pt.y.toFixed(3)},${pt.z.toFixed(3)}\n');
    }

    out.write('\n; === CONTOURS ===\n');
    for (final c in contours) {
      final layer = c.isMajor ? 'Contours-Major' : 'Contours-Minor';
      final z = c.level.toFixed(3);
      out
        ..write('-LAYER S $layer \n')
        ..write('3DPOLY ');
      for (final p in c.points) {
        out.write('${p.x.toFixed(3)},${p.y.toFixed(3)},$z ');
      }
      out.write('\n\n');
    }

    out
      ..write('; === BREAKLINES ===\n')
      ..write('-LAYER S Breaklines \n');
    for (final bl in breakLines) {
      out.write('3DPOLY ');
      for (final p in bl.points) {
        out.write('${p.x.toFixed(3)},${p.y.toFixed(3)},${p.z.toFixed(3)} ');
      }
      out.write('\n\n');
    }
    out.write('ZOOM E\n');
    return out.toString();
  }
}
