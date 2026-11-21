import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/js_number.dart';
import '../../../../core/widgets/app_modal.dart';
import '../controllers/contour_controller.dart';
import '../controllers/display_settings_controller.dart';
import '../painters/chart_data.dart';
import '../widgets/panels/data_tab.dart' show StatKind;
import 'stat_details_data.dart';

/// Opens the statistic details modal (reference lines 4166–4354).
Future<void> showStatDetailsDialog(BuildContext context, StatKind kind) =>
    showAppModal<void>(context, builder: (_) => StatDetailsDialog(kind: kind));

/// "Borehole / Breakline / Triangle / Contour Statistics" modal.
class StatDetailsDialog extends StatelessWidget {
  const StatDetailsDialog({required this.kind, super.key});

  final StatKind kind;

  static String titleOf(StatKind kind) => switch (kind) {
    StatKind.boreholes => '📍 Borehole Statistics',
    StatKind.breaklines => '〰️ Breakline Statistics',
    StatKind.triangles => '△ Triangle Statistics',
    StatKind.contours => '🗺 Contour Statistics',
  };

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: titleOf(kind),
      maxWidth: 500,
      onClose: () => Navigator.of(context).pop(),
      child: switch (kind) {
        StatKind.boreholes => const _BoreholeStats(),
        StatKind.breaklines => const _BreaklineStats(),
        StatKind.triangles => const _TriangleStats(),
        StatKind.contours => const _ContourStats(),
      },
    );
  }
}

// ---- shared building blocks ---------------------------------------------------

TextStyle get _body =>
    AppText.ui(13, color: AppColors.textSecondary, height: 1.8);

TextSpan _strong(String text, {Color? color}) => TextSpan(
  text: text,
  style: TextStyle(fontWeight: FontWeight.w700, color: color),
);

TextSpan _tint(String text, Color color) => TextSpan(
  text: text,
  style: TextStyle(color: color),
);

class _Layout extends StatelessWidget {
  const _Layout({
    required this.value,
    required this.color,
    required this.children,
  });

  final String value;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: AppText.mono(48, color: color, weight: FontWeight.w700),
          ),
        ),
        DefaultTextStyle(
          style: _body,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SourceBox extends StatelessWidget {
  const _SourceBox({
    required this.color,
    required this.label,
    required this.text,
  });

  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            _strong('$label ', color: AppColors.textPrimary),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(_strong(text, color: AppColors.textPrimary)),
  );
}

class _Indented extends StatelessWidget {
  const _Indented({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// `• <strong>label:</strong> <span>value</span>` or a plain bullet.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text) : label = null, value = null, valueColor = null;

  const _Bullet.stat({
    required String this.label,
    required String this.value,
    required Color this.valueColor,
  }) : text = '';

  final String text;
  final String? label;
  final String? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final l = label;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '• '),
          if (l == null)
            TextSpan(text: text)
          else ...[
            _strong(l),
            const TextSpan(text: ' '),
            _tint(value ?? '', valueColor ?? AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: '• '),
        _strong(text),
      ],
    ),
  );
}

class _Tip extends StatelessWidget {
  const _Tip({required this.color, required this.label, required this.text});

  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(
          style: AppText.ui(12, color: color, height: 1.8),
          children: [
            const TextSpan(text: '💡 '),
            _strong(label),
            TextSpan(text: ' $text'),
          ],
        ),
      ),
    );
  }
}

// ---- boreholes ----------------------------------------------------------------

class _BoreholeStats extends StatelessWidget {
  const _BoreholeStats();

  @override
  Widget build(BuildContext context) {
    final points = context.watch<ContourController>().points;
    final e = elevationExtent(points);
    final valid = !e.min.isNaN && !e.max.isNaN;
    return _Layout(
      value: '${points.length}',
      color: AppColors.accentCyan,
      children: [
        const _SourceBox(
          color: AppColors.accentCyan,
          label: 'Source:',
          text: 'Survey points imported from Excel file with X, Y, Z coordinates and identifiers',
        ),
        const _Heading('Elevation Range:'),
        _Indented(
          children: valid
              ? [
                  _Bullet.stat(
                    label: 'Minimum RL:',
                    value: '${e.min.toFixed(3)}m',
                    valueColor: AppColors.accentCyan,
                  ),
                  _Bullet.stat(
                    label: 'Maximum RL:',
                    value: '${e.max.toFixed(3)}m',
                    valueColor: AppColors.accentGreen,
                  ),
                  _Bullet.stat(
                    label: 'Relief:',
                    value: '${(e.max - e.min).toFixed(3)}m',
                    valueColor: AppColors.accentOrange,
                  ),
                ]
              : const [_NoData('No elevation data available')],
        ),
        const _Heading('Purpose:'),
        const _Indented(
          children: [
            _Bullet('Define terrain surface for TIN generation'),
            _Bullet('Serve as control points for triangulation'),
            _Bullet('Establish elevation reference network'),
          ],
        ),
        const _Tip(
          color: AppColors.accentCyan,
          label: 'Tip:',
          text: 'Higher point density improves contour accuracy in areas with complex terrain',
        ),
      ],
    );
  }
}

// ---- breaklines ---------------------------------------------------------------

class _BreaklineStats extends StatelessWidget {
  const _BreaklineStats();

  @override
  Widget build(BuildContext context) {
    final lines = context.watch<ContourController>().breakLines;
    final t = BreaklineTotals.of(lines);
    return _Layout(
      value: '${lines.length}',
      color: AppColors.accentOrange,
      children: [
        const _SourceBox(
          color: AppColors.accentOrange,
          label: 'Source:',
          text: 'Manual drawing + Excel import of terrain features',
        ),
        const _Heading('Total Segments:'),
        _Indented(
          children: [
            _Bullet.stat(
              label: 'Line Segments:',
              value: '${t.segments}',
              valueColor: AppColors.accentOrange,
            ),
            _Bullet.stat(
              label: 'Total Length:',
              value: '${t.totalLength.toFixed(2)}m',
              valueColor: AppColors.accentOrange,
            ),
            _Bullet.stat(
              label: 'Avg per Line:',
              value: lines.isEmpty ? '0m' : '${t.averageLength.toFixed(2)}m',
              valueColor: AppColors.accentOrange,
            ),
          ],
        ),
        const _Heading('Function:'),
        const _Indented(
          children: [
            _Bullet('Enforce terrain discontinuities (ridges, valleys)'),
            _Bullet('Constrain Delaunay triangulation edges'),
            _Bullet('Prevent contours crossing features'),
            _Bullet('Define drainage patterns and structures'),
          ],
        ),
        const _Tip(
          color: AppColors.accentOrange,
          label: 'Tip:',
          text: 'Draw breaklines along ridgelines, embankments, roads, and drainage channels for realistic terrain',
        ),
      ],
    );
  }
}

// ---- triangles ----------------------------------------------------------------

class _TriangleStats extends StatelessWidget {
  const _TriangleStats();

  @override
  Widget build(BuildContext context) {
    final triangles = context.watch<ContourController>().model.triangles;
    final a = TriangleAreaStats.of(triangles);
    const purple = AppColors.accentPurple;
    return _Layout(
      value: '${triangles.length}',
      color: purple,
      children: [
        const _SourceBox(
          color: purple,
          label: 'Method:',
          text: 'Constrained Delaunay Triangulation with breakline enforcement',
        ),
        const _Heading('Mesh Properties:'),
        _Indented(
          children: a == null
              ? const [_NoData('No triangles generated yet')]
              : [
                  _Bullet.stat(
                    label: 'Total Coverage:',
                    value: '${a.total.toFixed(2)}m²',
                    valueColor: purple,
                  ),
                  _Bullet.stat(
                    label: 'Avg Triangle:',
                    value: '${a.average.toFixed(2)}m²',
                    valueColor: purple,
                  ),
                  _Bullet.stat(
                    label: 'Size Range:',
                    value: '${a.min.toFixed(2)} - ${a.max.toFixed(2)}m²',
                    valueColor: purple,
                  ),
                ],
        ),
        const _Heading('TIN Algorithm:'),
        const _Indented(
          children: [
            _Bullet('Delaunay criterion: maximizes minimum angle'),
            _Bullet('Avoids sliver triangles for stability'),
            _Bullet('Respects breakline constraints'),
            _Bullet('Creates surface for contour interpolation'),
          ],
        ),
        const _Tip(
          color: purple,
          label: 'Quality:',
          text: 'Well-conditioned triangles ensure accurate surface interpolation between survey points',
        ),
      ],
    );
  }
}

// ---- contours -----------------------------------------------------------------

class _ContourStats extends StatelessWidget {
  const _ContourStats();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ContourController>();
    final showLabels = context.select<DisplaySettingsController, bool>(
      (d) => d.showLabels,
    );
    final interval = jsNumber(c.interval);
    return _Layout(
      value: '${c.model.contours.length}',
      color: AppColors.accentGreen,
      children: [
        _SourceBox(
          color: AppColors.accentGreen,
          label: 'Method:',
          text:
              'Linear interpolation across TIN triangle edges at ${interval}m intervals',
        ),
        const _Heading('Interval Settings:'),
        _Indented(
          children: [
            _Bullet.stat(
              label: 'Minor Contours:',
              value: 'Every ${interval}m',
              valueColor: AppColors.accentGreen,
            ),
            _Bullet.stat(
              label: 'Major Contours:',
              value: 'Every ${c.majorEvery}m',
              valueColor: AppColors.accentRed,
            ),
            _Bullet.stat(
              label: 'Labels:',
              value: showLabels ? 'Enabled' : 'Disabled',
              valueColor: showLabels
                  ? AppColors.accentCyan
                  : AppColors.textMuted,
            ),
          ],
        ),
        const _Heading('Elevation Coverage:'),
        _Indented(children: _coverage(c)),
        const _Heading('Applications:'),
        const _Indented(
          children: [
            _Bullet('Site grading and earthwork planning'),
            _Bullet('Drainage design and watershed analysis'),
            _Bullet('Road/structure layout and alignment'),
            _Bullet('Cut/fill volume estimation'),
          ],
        ),
        const _Tip(
          color: AppColors.accentGreen,
          label: 'Accuracy:',
          text: 'Contour smoothness depends on borehole density and breakline placement',
        ),
      ],
    );
  }

  List<Widget> _coverage(ContourController c) {
    final e = elevationExtent(c.points);
    if (e.min.isNaN || e.max.isNaN) {
      return const [_NoData('No elevation data available')];
    }
    final cov = ContourCoverage.of(e.min, e.max, c.interval);
    return [
      _Bullet.stat(
        label: 'Lowest:',
        value: '${cov.lowest.toFixed(1)}m RL',
        valueColor: AppColors.accentCyan,
      ),
      _Bullet.stat(
        label: 'Highest:',
        value: '${cov.highest.toFixed(1)}m RL',
        valueColor: AppColors.accentGreen,
      ),
      _Bullet.stat(
        label: 'Span:',
        value: '${cov.span.toFixed(1)}m (${cov.levels} levels)',
        valueColor: AppColors.accentOrange,
      ),
    ];
  }
}
