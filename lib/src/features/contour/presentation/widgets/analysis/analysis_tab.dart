import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/js_number.dart';
import '../../../domain/entities/geometry.dart';
import '../../../domain/entities/terrain.dart';
import '../../../domain/entities/triangle.dart';
import '../../controllers/contour_controller.dart';
import '../../dialogs/expanded_chart_dialog.dart';
import '../../painters/chart_data.dart';
import '../../painters/viz_style.dart';
import 'analysis_cards.dart';
import 'analysis_charts.dart';
import 'tin_visualizer.dart';

/// Contents of the sidebar "◔ Analysis" tab (reference lines 3541–3652).
class AnalysisTab extends StatelessWidget {
  const AnalysisTab({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.select<ContourController, TerrainStats?>(
      (c) => c.model.stats,
    );
    if (stats == null) return const _EmptyAnalysis();
    return _AnalysisBody(stats: stats);
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('📊', style: TextStyle(fontSize: 32)),
            ),
            Text(
              'Import data to view terrain analysis',
              style: VizStyle.sans(14, AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({required this.stats});

  final TerrainStats stats;

  @override
  Widget build(BuildContext context) {
    final points = context.select<ContourController, List<SurveyPoint>>(
      (c) => c.points,
    );
    final breakLines = context.select<ContourController, List<BreakLine>>(
      (c) => c.breakLines,
    );
    final triangles = context.select<ContourController, List<Triangle>>(
      (c) => c.model.triangles,
    );
    final summary = context.select<ContourController, TerrainSummary?>(
      (c) => c.summary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OverviewCard(stats: stats),
        if (triangles.isNotEmpty)
          TinVisualizer(
            points: points,
            triangles: triangles,
            breakLines: breakLines,
            onExpand: () =>
                ExpandedChartDialog.show(context, ExpandedChartKind.tin),
          ),
        _ElevationCard(stats: stats.elevation),
        _SlopeCard(stats: stats),
        _ElevationChartCard(points: points),
        if (triangles.isNotEmpty) _SlopeChartCard(triangles: triangles),
        if (summary != null) _SummaryAiCard(summary: summary),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats});

  final TerrainStats stats;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      title: '🗺 Terrain Overview',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(child: TerrainBadge.forType(stats.terrainType)),
        ),
        SummaryItem(label: 'Survey Area', value: '${stats.area.toFixed(1)} m²'),
        SummaryItem(
          label: 'Points / Triangles',
          value: '${stats.pointCount} / ${stats.triangleCount}',
        ),
      ],
    );
  }
}

class _ElevationCard extends StatelessWidget {
  const _ElevationCard({required this.stats});

  final ElevationStats stats;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      title: '📊 Elevation Statistics',
      children: [
        SummaryItem(
          label: 'Minimum RL',
          value: '${stats.min.toFixed(2)} m',
          valueColor: AppColors.accentCyan,
        ),
        SummaryItem(
          label: 'Maximum RL',
          value: '${stats.max.toFixed(2)} m',
          valueColor: AppColors.accentGreen,
        ),
        SummaryItem(label: 'Average RL', value: '${stats.avg.toFixed(2)} m'),
        SummaryItem(
          label: 'Relief (Range)',
          value: '${stats.range.toFixed(2)} m',
          valueColor: AppColors.accentOrange,
        ),
      ],
    );
  }
}

class _SlopeCard extends StatelessWidget {
  const _SlopeCard({required this.stats});

  final TerrainStats stats;

  @override
  Widget build(BuildContext context) {
    final d = stats.slopeDistribution;
    return SummaryCard(
      title: '📐 Slope Analysis',
      children: [
        SummaryItem(
          label: 'Average Slope',
          value: '${stats.slope.avgDeg.toFixed(1)}°',
        ),
        SummaryItem(
          label: 'Max Slope',
          value: '${stats.slope.maxDeg.toFixed(1)}°',
          valueColor: AppColors.accentRed,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Slope Distribution:',
                  style: VizStyle.sans(10, AppColors.textMuted),
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TerrainBadge(
                    text: 'Flat: ${d.flat}',
                    color: AppColors.accentGreen,
                  ),
                  TerrainBadge(
                    text: 'Gentle: ${d.gentle}',
                    color: AppColors.accentCyan,
                  ),
                  TerrainBadge(
                    text: 'Mod: ${d.moderate}',
                    color: AppColors.accentYellow,
                  ),
                  TerrainBadge(
                    text: 'Steep: ${d.steep}',
                    color: AppColors.accentOrange,
                  ),
                  TerrainBadge(
                    text: 'Ext: ${d.extreme}',
                    color: AppColors.accentRed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ElevationChartCard extends StatefulWidget {
  const _ElevationChartCard({required this.points});

  final List<SurveyPoint> points;

  @override
  State<_ElevationChartCard> createState() => _ElevationChartCardState();
}

class _ElevationChartCardState extends State<_ElevationChartCard> {
  late List<ElevationSample> _samples = sortedElevations(widget.points);

  @override
  void didUpdateWidget(_ElevationChartCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.points, widget.points)) {
      _samples = sortedElevations(widget.points);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChartContainer(
      title: '📊 Elevation Profile',
      expandTooltip: 'Expand chart',
      onExpand: () =>
          ExpandedChartDialog.show(context, ExpandedChartKind.elevation),
      child: _samples.isEmpty
          ? const SizedBox(height: 200)
          : ElevationChart(samples: _samples),
    );
  }
}

class _SlopeChartCard extends StatefulWidget {
  const _SlopeChartCard({required this.triangles});

  final List<Triangle> triangles;

  @override
  State<_SlopeChartCard> createState() => _SlopeChartCardState();
}

class _SlopeChartCardState extends State<_SlopeChartCard> {
  late SlopeAnalysis _analysis = SlopeAnalysis.fromTriangles(widget.triangles);

  @override
  void didUpdateWidget(_SlopeChartCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.triangles, widget.triangles)) {
      _analysis = SlopeAnalysis.fromTriangles(widget.triangles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChartContainer(
      title: '📐 Slope Distribution',
      expandTooltip: 'Expand chart',
      onExpand: () =>
          ExpandedChartDialog.show(context, ExpandedChartKind.slope),
      child: SlopeChart(analysis: _analysis),
    );
  }
}

class _SummaryAiCard extends StatelessWidget {
  const _SummaryAiCard({required this.summary});

  final TerrainSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = summary.paragraphs;
    final body = VizStyle.sans(11, AppColors.textSecondary, height: 1.7);
    return SummaryCard(
      title: '🤖 AI Terrain Analysis',
      gradient: true,
      titleWidget: Row(
        children: [
          Flexible(
            child: Text(
              '🤖 AI Terrain Analysis',
              style: VizStyle.sans(
                12,
                AppColors.accentCyan,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Smart Summary',
              style: VizStyle.sans(9, AppColors.accentGreen),
            ),
          ),
        ],
      ),
      children: [
        for (final i in [0, 1, 2])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(p[i], style: body),
          ),
        if (p[3].isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(p[3], style: body),
          ),
        _Assessment(text: p[4], style: body),
      ],
    );
  }
}

class _Assessment extends StatelessWidget {
  const _Assessment({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: AppColors.accentPurple, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '📋 Assessment & Recommendations',
              style: VizStyle.sans(
                10,
                AppColors.accentPurple,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Text(text, style: style),
        ],
      ),
    );
  }
}
