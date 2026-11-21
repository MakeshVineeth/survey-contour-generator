// Renders the Google Play store screenshots from the REAL app UI with the
// built-in sample data, real bundled fonts and the app's own widgets.
//
//   flutter test tool/store_assets/capture_screenshots_test.dart
//
// Output (all opaque 24-bit RGB PNGs, as Play requires):
//   .docs/play-store/assets/phone/*.png            1080x1920
//   .docs/play-store/assets/phone-captioned/*.png  1080x1920 (marketing)
//   .docs/play-store/assets/tablet-7in/*.png       1200x1920
//   .docs/play-store/assets/tablet-10in/*.png      1600x2560
//
// This file lives in tool/ on purpose, so the normal `flutter test` (which only
// scans test/) never runs it.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_contour_generator/src/features/contour/presentation/widgets/shell/sidebar.dart';

import '../../test/helpers/pump_app.dart';

const String _outDir = '.docs/play-store/assets';

// ---- fonts ------------------------------------------------------------------

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final path in files) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _loadAllFonts() async {
  const o = 'assets/fonts/outfit/Outfit-';
  const j = 'assets/fonts/jetbrains_mono/JetBrainsMono-';
  const n = 'assets/fonts/noto_emoji/';
  await _loadFont('Outfit', [
    '${o}Light.ttf',
    '${o}Regular.ttf',
    '${o}Medium.ttf',
    '${o}SemiBold.ttf',
    '${o}Bold.ttf',
  ]);
  await _loadFont('JetBrainsMono', [
    '${j}Regular.ttf',
    '${j}Medium.ttf',
    '${j}SemiBold.ttf',
  ]);
  await _loadFont('NotoColorEmoji', ['${n}NotoColorEmoji-Subset.ttf']);
  await _loadFont('NotoSansSymbols', ['${n}NotoSansSymbols-Subset.ttf']);
  await _loadFont('NotoSansSymbols2', ['${n}NotoSansSymbols2-Subset.ttf']);
  await _loadFont('NotoSansMath', ['${n}NotoSansMath-Subset.ttf']);
  await _loadFont('NotoSansJP', ['${n}NotoSansJP-Subset.otf']);
}

// ---- PNG (colour type 2 = opaque RGB) ----------------------------------------

/// Straight RGBA pixels.
class _Raw {
  const _Raw(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _chunk(String type, List<int> data) {
  final out = BytesBuilder();
  final typeBytes = type.codeUnits;
  out
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(typeBytes)
    ..add(data)
    ..add(
      (ByteData(
        4,
      )..setUint32(0, _crc32([...typeBytes, ...data]))).buffer.asUint8List(),
    );
  return out.toBytes();
}

/// Encodes [raw] as a 24-bit RGB PNG, flattening any alpha onto [flatten].
Uint8List _encodeRgbPng(_Raw raw, {int flatten = 0x0A0E14}) {
  final w = raw.width;
  final h = raw.height;
  final br = (flatten >> 16) & 0xFF;
  final bg = (flatten >> 8) & 0xFF;
  final bb = flatten & 0xFF;
  final rows = Uint8List(h * (1 + w * 3));
  var o = 0;
  for (var y = 0; y < h; y++) {
    rows[o++] = 0; // filter: none
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final a = raw.rgba[i + 3];
      if (a == 255) {
        rows[o++] = raw.rgba[i];
        rows[o++] = raw.rgba[i + 1];
        rows[o++] = raw.rgba[i + 2];
      } else {
        rows[o++] = (raw.rgba[i] * a + br * (255 - a)) ~/ 255;
        rows[o++] = (raw.rgba[i + 1] * a + bg * (255 - a)) ~/ 255;
        rows[o++] = (raw.rgba[i + 2] * a + bb * (255 - a)) ~/ 255;
      }
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2); // colour type: truecolour, no alpha
  final out = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', ihdr.buffer.asUint8List()))
    ..add(_chunk('IDAT', ZLibCodec(level: 6).encode(rows)))
    ..add(_chunk('IEND', const []));
  return out.toBytes();
}

void _save(_Raw raw, String relPath) {
  final file = File('$_outDir/$relPath')..createSync(recursive: true);
  file.writeAsBytesSync(_encodeRgbPng(raw));
}

// ---- scene helpers ----------------------------------------------------------

class _Scene {
  _Scene(this.tester, this.h, this.key, this.ratio);
  final WidgetTester tester;
  final AppHarness h;
  final GlobalKey key;
  final double ratio;
}

/// Pumps the real app at [logical] size with device pixel ratio [ratio].
Future<_Scene> _open(
  WidgetTester tester,
  Size logical,
  double ratio, {
  bool sample = true,
}) async {
  tester.view
    ..physicalSize = logical * ratio
    ..devicePixelRatio = ratio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = AppHarness();
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: h.app));
  addTearDown(() async {
    await tester.pump(const Duration(seconds: 5));
    h.contours.dispose();
    h.display.dispose();
    h.view.dispose();
    h.draw.dispose();
  });
  final scene = _Scene(tester, h, key, ratio);
  if (sample) {
    await h.loadSample(tester);
    await _settle(tester, seconds: 4); // let the "Sample loaded" toast go
  }
  return scene;
}

Future<void> _settle(WidgetTester tester, {double seconds = 1}) async {
  final steps = (seconds * 10).round();
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openDrawer(_Scene s) async {
  await s.tester.tap(find.text('☰').first);
  await _settle(s.tester);
}

Future<void> _selectTab(_Scene s, String label) async {
  await s.tester.tap(find.text(label));
  await _settle(s.tester);
}

/// Scrolls the sidebar so [target] sits [margin] logical px below its top edge.
Future<void> _scrollSidebarTo(
  _Scene s,
  Finder target, {
  double margin = 8,
}) async {
  final scrollable = find
      .descendant(of: find.byType(Sidebar), matching: find.byType(Scrollable))
      .first;
  final state = s.tester.state<ScrollableState>(scrollable);
  final top = s.tester.getTopLeft(scrollable).dy;
  final dy = s.tester.getTopLeft(target).dy - top - margin;
  state.position.jumpTo(
    (state.position.pixels + dy).clamp(
      state.position.minScrollExtent,
      state.position.maxScrollExtent,
    ),
  );
  await _settle(s.tester, seconds: 0.5);
}

Future<_Raw> _grab(_Scene s) async {
  final raw = await s.tester.runAsync<_Raw>(() async {
    final boundary =
        s.key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: s.ratio);
    final data = await image.toByteData();
    final r = _Raw(image.width, image.height, data!.buffer.asUint8List());
    image.dispose();
    return r;
  });
  return raw!;
}

// ---- captioned marketing variant ---------------------------------------------

const double _capW = 1080;
const double _capH = 1920;
const double _capShotScale = 0.85;
const double _capBottomMargin = 36;

/// Headlines: the word in [brackets] is rendered in the brand cyan.
const List<String> _headlines = [
  'Contour maps in [seconds]',
  'Import [Excel] survey data',
  '[Terrain analysis] built in',
  'Elevation and [slope] charts',
  'Export to [AutoCAD] and more',
  'Draw [breaklines] on the map',
];

TextSpan _headlineSpan(String text) {
  const base = TextStyle(
    fontFamily: 'Outfit',
    fontWeight: FontWeight.w600,
    fontSize: 64,
    height: 1.1,
    color: Color(0xFFFFFFFF),
  );
  final spans = <InlineSpan>[];
  final re = RegExp(r'\[([^\]]+)\]');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(
      TextSpan(
        text: m.group(1),
        style: const TextStyle(color: Color(0xFF00D9FF)),
      ),
    );
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: base, children: spans);
}

Future<_Raw> _caption(WidgetTester tester, _Raw shot, String headline) async {
  final raw = await tester.runAsync<_Raw>(() async {
    final shotImage = await _decode(shot);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const full = Rect.fromLTWH(0, 0, _capW, _capH);
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(_capW, _capH),
          const [Color(0xFF0A0E14), Color(0xFF141C29)],
        ),
    );
    _glow(canvas, const Offset(160, 120), 700, const Color(0xFF00D9FF), 0.16);
    _glow(canvas, const Offset(960, 1500), 800, const Color(0xFFA855F7), 0.14);

    final tp = TextPainter(
      text: _headlineSpan(headline),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _capW - 80);
    final shotW = _capW * _capShotScale;
    final shotH = shotW * shot.height / shot.width;
    final shotTop = _capH - _capBottomMargin - shotH;
    tp.paint(
      canvas,
      Offset((_capW - tp.width) / 2, (shotTop - tp.height) / 2 + 4),
    );

    final dst = Rect.fromLTWH((_capW - shotW) / 2, shotTop, shotW, shotH);
    final rrect = RRect.fromRectXY(dst, 36, 36);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 18)),
      Paint()
        ..color = const Color(0xAA000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas
      ..save()
      ..clipRRect(rrect, doAntiAlias: true)
      ..drawImageRect(
        shotImage,
        Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.high,
      )
      ..restore()
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2D3748),
      );
    final picture = recorder.endRecording();
    final out = await picture.toImage(_capW.toInt(), _capH.toInt());
    final data = await out.toByteData();
    final r = _Raw(out.width, out.height, data!.buffer.asUint8List());
    out.dispose();
    shotImage.dispose();
    picture.dispose();
    return r;
  });
  return raw!;
}

void _glow(Canvas canvas, Offset c, double radius, Color color, double alpha) {
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(c, radius, [
        color.withValues(alpha: alpha),
        color.withValues(alpha: 0),
      ]),
  );
}

Future<ui.Image> _decode(_Raw raw) {
  final completer = Future<ui.Image>.sync(() async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(raw.rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: raw.width,
      height: raw.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  });
  return completer;
}

// ---- the shots ----------------------------------------------------------------

const Size _phone = Size(360, 640);
const double _phoneRatio = 3;

typedef _Setup = Future<void> Function(_Scene s);

Future<void> _breaklineDemo(_Scene s) async {
  s.h.display.showLabels = false; // keep the drawn line uncluttered
  s.h.draw.toggleDrawMode();
  await _settle(s.tester, seconds: 0.5); // toolbar grows -> viewport refit
  s.h.view.zoomCentered(1.3);
  for (final p in const [
    [85.0, 215.0],
    [128.0, 195.0],
    [170.0, 165.0],
    [215.0, 178.0],
    [262.0, 200.0],
  ]) {
    s.h.draw.addPointAt(p[0], p[1]);
  }
  await _settle(s.tester, seconds: 4); // let the toasts go
}

Future<void> _noop(_Scene s) async {}

/// Phone hero: a user-style zoom so the survey fills the narrow screen.
Future<void> _phoneMap(_Scene s) async {
  s.h.view.zoomCentered(1.3);
  await _settle(s.tester, seconds: 0.5);
}

Future<void> _phoneData(_Scene s) async {
  await _openDrawer(s);
}

Future<void> _phoneAnalysisTin(_Scene s) async {
  await _openDrawer(s);
  await _selectTab(s, '◔ Analysis');
  await _scrollSidebarTo(
    s,
    find.text('△ TIN Construction Visualizer'),
    margin: 30,
  );
}

Future<void> _phoneAnalysisCharts(_Scene s) async {
  await _openDrawer(s);
  await _selectTab(s, '◔ Analysis');
  await _scrollSidebarTo(s, find.text('📊 Elevation Profile'), margin: 30);
}

Future<void> _exportDialog(_Scene s) async {
  await s.tester.tap(find.text('📤'));
  await _settle(s.tester);
}

Future<void> _desktopExport(_Scene s) async {
  await s.tester.tap(find.text('Export'));
  await _settle(s.tester);
}

Future<void> _phoneDraw(_Scene s) async {
  await _breaklineDemo(s);
}

Future<void> _tabletAnalysis(_Scene s) async {
  await _selectTab(s, '◔ Analysis');
}

Future<void> _mobileTabletAnalysis(_Scene s) async {
  await _openDrawer(s);
  await _selectTab(s, '◔ Analysis');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadAllFonts);

  final phoneShots = <(String, _Setup)>[
    ('01-map', _phoneMap),
    ('02-data', _phoneData),
    ('03-analysis-tin', _phoneAnalysisTin),
    ('04-analysis-charts', _phoneAnalysisCharts),
    ('05-export', _exportDialog),
    ('06-draw', _phoneDraw),
  ];

  for (var i = 0; i < phoneShots.length; i++) {
    final (name, setup) = phoneShots[i];
    testWidgets('phone $name', (tester) async {
      final s = await _open(tester, _phone, _phoneRatio);
      await setup(s);
      final raw = await _grab(s);
      expect((raw.width, raw.height), (1080, 1920));
      _save(raw, 'phone/$name.png');
      final captioned = await _caption(tester, raw, _headlines[i]);
      _save(captioned, 'phone-captioned/$name.png');
    });
  }

  final tablet10 = <(String, _Setup)>[
    ('01-map', _noop),
    ('02-analysis', _tabletAnalysis),
    ('03-export', _desktopExport),
  ];
  for (final (name, setup) in tablet10) {
    testWidgets('tablet-10in $name', (tester) async {
      final s = await _open(tester, const Size(800, 1280), 2);
      await setup(s);
      final raw = await _grab(s);
      expect((raw.width, raw.height), (1600, 2560));
      _save(raw, 'tablet-10in/$name.png');
    });
  }

  final tablet7 = <(String, _Setup)>[
    ('01-map', _noop),
    ('02-analysis', _mobileTabletAnalysis),
    ('03-export', _exportDialog),
  ];
  for (final (name, setup) in tablet7) {
    testWidgets('tablet-7in $name', (tester) async {
      final s = await _open(tester, const Size(600, 960), 2);
      await setup(s);
      final raw = await _grab(s);
      expect((raw.width, raw.height), (1200, 1920));
      _save(raw, 'tablet-7in/$name.png');
    });
  }
}
