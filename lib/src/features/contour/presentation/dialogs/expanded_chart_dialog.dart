import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../domain/entities/geometry.dart';
import '../../domain/entities/triangle.dart';
import '../controllers/contour_controller.dart';
import '../painters/chart_data.dart';
import '../painters/elevation_chart_painter.dart';
import '../widgets/analysis/analysis_charts.dart';
import '../widgets/analysis/tin_visualizer.dart';

/// Which visualization the expanded modal shows (reference `expandedChart`).
enum ExpandedChartKind { elevation, slope, tin }

/// Modal with a large chart or the TIN visualizer (reference lines 4356–4382:
/// `rgba(0,0,0,0.85)` blurred overlay, 800px panel).
class ExpandedChartDialog extends StatelessWidget {
  const ExpandedChartDialog({required this.kind, super.key});

  final ExpandedChartKind kind;

  /// Shows the modal above the current route.
  static Future<void> show(BuildContext context, ExpandedChartKind kind) =>
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: const Color(0xD9000000),
        transitionDuration: Duration.zero,
        pageBuilder: (ctx, _, _) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ExpandedChartDialog(kind: kind),
        ),
      );

  static String titleOf(ExpandedChartKind kind) => switch (kind) {
    ExpandedChartKind.elevation => '📊 Elevation Profile',
    ExpandedChartKind.slope => '📐 Slope Distribution',
    ExpandedChartKind.tin => '△ TIN Construction Visualizer',
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(800.0, media.size.width * 0.9);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Center(
          child: Container(
            width: width,
            constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  title: titleOf(kind),
                  onClose: () => Navigator.of(context).pop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _Body(kind: kind),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: AppText.ui(
                16,
                color: AppColors.accentCyan,
                weight: FontWeight.w600,
              ),
            ),
          ),
          ModalCloseButton(onClose: onClose),
        ],
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.kind});

  final ExpandedChartKind kind;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  List<SurveyPoint>? _samplePoints;
  List<ElevationSample> _samples = const [];
  List<Triangle>? _slopeTriangles;
  SlopeAnalysis? _analysis;

  List<ElevationSample> _elevations(List<SurveyPoint> points) {
    if (!identical(_samplePoints, points)) {
      _samplePoints = points;
      _samples = sortedElevations(points);
    }
    return _samples;
  }

  SlopeAnalysis _slopes(List<Triangle> triangles) {
    if (!identical(_slopeTriangles, triangles) || _analysis == null) {
      _slopeTriangles = triangles;
      _analysis = SlopeAnalysis.fromTriangles(triangles);
    }
    return _analysis!;
  }

  @override
  Widget build(BuildContext context) {
    final points = context.select<ContourController, List<SurveyPoint>>(
      (c) => c.points,
    );
    final triangles = context.select<ContourController, List<Triangle>>(
      (c) => c.model.triangles,
    );
    switch (widget.kind) {
      case ExpandedChartKind.tin:
        final breakLines = context.select<ContourController, List<BreakLine>>(
          (c) => c.breakLines,
        );
        return TinVisualizer(
          points: points,
          triangles: triangles,
          breakLines: breakLines,
          isExpanded: true,
        );
      case ExpandedChartKind.elevation:
        final samples = _elevations(points);
        return samples.isEmpty
            ? const SizedBox(height: 400)
            : ElevationChart(
                samples: samples,
                style: ElevationChartStyle.large,
              );
      case ExpandedChartKind.slope:
        final analysis = _slopes(triangles);
        return analysis.total == 0
            ? const SizedBox(height: 400)
            : SlopeChart(analysis: analysis, expanded: true);
    }
  }
}
