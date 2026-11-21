import 'dart:math' as math;

import '../../../../core/utils/js_number.dart';
import '../entities/contour.dart';
import '../entities/geometry.dart';
import 'cad_text.dart';

/// Builds an AutoCAD DXF (R12 / AC1009) document: the most compatible flavour,
/// which needs no handles or subclass markers.
final class DxfExporter {
  const DxfExporter._();

  static String build(
    List<Contour> contours,
    List<BreakLine> breakLines,
    List<SurveyPoint> points,
  ) {
    final out = StringBuffer()
      ..write(_header)
      ..write('0\nSECTION\n2\nENTITIES\n');

    for (final c in contours) {
      _writeContour(out, c);
    }
    for (final bl in breakLines) {
      _writeBreakLine(out, bl);
    }
    for (final pt in points) {
      _writePoint(out, pt);
    }

    out
      ..write('0\nENDSEC\n')
      ..write('0\nEOF\n');
    return out.toString();
  }

  static void _writeContour(StringBuffer out, Contour c) {
    final layer = c.isMajor ? 'Contours-Major' : 'Contours-Minor';
    final z = c.level.toFixed(3);

    out
      ..write('0\nPOLYLINE\n8\n$layer\n66\n1\n70\n8\n')
      ..write('10\n0.0\n20\n0.0\n30\n$z\n');
    for (final p in c.points) {
      out
        ..write('0\nVERTEX\n8\n$layer\n')
        ..write('10\n${p.x.toFixed(3)}\n20\n${p.y.toFixed(3)}\n30\n$z\n')
        ..write('70\n32\n');
    }
    out.write('0\nSEQEND\n8\n$layer\n');

    if (c.points.length >= 3) _writeContourLabel(out, c, z);
  }

  static void _writeContourLabel(StringBuffer out, Contour c, String z) {
    final midIdx = c.points.length ~/ 2;
    final mid = c.points[midIdx];
    var angle = 0.0;
    if (midIdx > 0 && midIdx < c.points.length - 1) {
      final prev = c.points[midIdx - 1];
      final next = c.points[midIdx + 1];
      angle = _atan2Degrees(next.y - prev.y, next.x - prev.x);
    }
    out
      ..write('0\nTEXT\n8\nContour-Labels\n')
      ..write('10\n${mid.x.toFixed(3)}\n20\n${mid.y.toFixed(3)}\n30\n$z\n')
      ..write('40\n2.0\n')
      ..write('1\n${c.level.toFixed(1)}\n')
      ..write('50\n${angle.toFixed(1)}\n');
  }

  static void _writeBreakLine(StringBuffer out, BreakLine bl) {
    out
      ..write('0\nPOLYLINE\n8\nBreaklines\n66\n1\n70\n8\n')
      ..write('10\n0.0\n20\n0.0\n30\n0.0\n');
    for (final p in bl.points) {
      out
        ..write('0\nVERTEX\n8\nBreaklines\n')
        ..write('10\n${p.x.toFixed(3)}\n20\n${p.y.toFixed(3)}\n30\n${p.z.toFixed(3)}\n')
        ..write('70\n32\n');
    }
    out.write('0\nSEQEND\n8\nBreaklines\n');
  }

  static void _writePoint(StringBuffer out, SurveyPoint pt) {
    final z = pt.z.toFixed(3);
    out
      ..write('0\nPOINT\n8\nSurvey-Points\n')
      ..write('10\n${pt.x.toFixed(3)}\n20\n${pt.y.toFixed(3)}\n30\n$z\n')
      ..write('0\nTEXT\n8\nSurvey-Points\n')
      ..write('10\n${(pt.x + 1).toFixed(3)}\n20\n${(pt.y + 1).toFixed(3)}\n30\n$z\n')
      ..write('40\n1.5\n')
      ..write('1\n${sanitizeCadText(pt.borehole)} RL${pt.z.toFixed(2)}\n');
  }

  static double _atan2Degrees(double dy, double dx) =>
      math.atan2(dy, dx) * (180 / math.pi);

  static const String _header = '0\nSECTION\n2\nHEADER\n'
      '9\n\$ACADVER\n1\nAC1009\n'
      '9\n\$INSUNITS\n70\n6\n'
      '9\n\$EXTMIN\n10\n0.0\n20\n0.0\n30\n0.0\n'
      '9\n\$EXTMAX\n10\n1000000.0\n20\n1000000.0\n30\n10000.0\n'
      '0\nENDSEC\n'
      '0\nSECTION\n2\nTABLES\n'
      '0\nTABLE\n2\nLTYPE\n70\n1\n'
      '0\nLTYPE\n2\nCONTINUOUS\n70\n0\n3\nSolid line\n72\n65\n73\n0\n40\n0.0\n'
      '0\nENDTAB\n'
      '0\nTABLE\n2\nLAYER\n70\n6\n'
      '0\nLAYER\n2\n0\n70\n0\n62\n7\n6\nCONTINUOUS\n'
      '0\nLAYER\n2\nContours-Minor\n70\n0\n62\n3\n6\nCONTINUOUS\n'
      '0\nLAYER\n2\nContours-Major\n70\n0\n62\n1\n6\nCONTINUOUS\n'
      '0\nLAYER\n2\nContour-Labels\n70\n0\n62\n2\n6\nCONTINUOUS\n'
      '0\nLAYER\n2\nBreaklines\n70\n0\n62\n6\n6\nCONTINUOUS\n'
      '0\nLAYER\n2\nSurvey-Points\n70\n0\n62\n4\n6\nCONTINUOUS\n'
      '0\nENDTAB\n'
      '0\nTABLE\n2\nSTYLE\n70\n1\n'
      '0\nSTYLE\n2\nSTANDARD\n70\n0\n40\n0.0\n41\n1.0\n50\n0.0\n71\n0\n42\n2.5\n3\ntxt\n4\n\n'
      '0\nENDTAB\n'
      '0\nENDSEC\n'
      '0\nSECTION\n2\nBLOCKS\n'
      '0\nENDSEC\n';
}
