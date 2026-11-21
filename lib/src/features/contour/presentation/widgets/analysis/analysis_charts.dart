import 'package:material_ui/material_ui.dart';

import '../../painters/chart_data.dart';
import '../../painters/elevation_chart_painter.dart';
import '../../painters/slope_chart_painter.dart';

/// Elevation profile chart with hover/tap tooltips.
class ElevationChart extends StatefulWidget {
  const ElevationChart({
    required this.samples,
    this.style = ElevationChartStyle.compact,
    super.key,
  });

  final List<ElevationSample> samples;
  final ElevationChartStyle style;

  @override
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  int? _hover;

  void _update(Offset local, Size size) {
    if (widget.samples.isEmpty) return;
    final layout = ElevationChartLayout(size, widget.samples, widget.style);
    final inside = layout.plot.inflate(8).contains(local);
    final next = inside ? layout.indexAt(local.dx) : null;
    if (next != _hover) setState(() => _hover = next);
  }

  void _clear() {
    if (_hover != null) setState(() => _hover = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, widget.style.height);
        return MouseRegion(
          onHover: (e) => _update(e.localPosition, size),
          onExit: (_) => _clear(),
          child: Listener(
            onPointerDown: (e) => _update(e.localPosition, size),
            onPointerMove: (e) => _update(e.localPosition, size),
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: ElevationChartPainter(
                  samples: widget.samples,
                  style: widget.style,
                  hoverIndex: _hover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slope-class donut with hover/tap tooltips.
class SlopeChart extends StatefulWidget {
  const SlopeChart({required this.analysis, this.expanded = false, super.key});

  final SlopeAnalysis analysis;
  final bool expanded;

  @override
  State<SlopeChart> createState() => _SlopeChartState();
}

class _SlopeChartState extends State<SlopeChart> {
  int? _hover;

  void _update(Offset local, Size size) {
    final bins = widget.analysis.nonEmpty;
    if (bins.isEmpty) return;
    final layout = SlopeChartLayout(size, bins, expanded: widget.expanded);
    final next = layout.hitTest(local);
    if (next != _hover) setState(() => _hover = next);
  }

  void _clear() {
    if (_hover != null) setState(() => _hover = null);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.expanded ? 420.0 : 220.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        return MouseRegion(
          onHover: (e) => _update(e.localPosition, size),
          onExit: (_) => _clear(),
          child: Listener(
            onPointerDown: (e) => _update(e.localPosition, size),
            onPointerMove: (e) => _update(e.localPosition, size),
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: SlopeChartPainter(
                  analysis: widget.analysis,
                  expanded: widget.expanded,
                  hoverIndex: _hover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
