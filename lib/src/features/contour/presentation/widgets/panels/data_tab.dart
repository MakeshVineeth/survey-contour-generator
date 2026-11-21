import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/utils/js_number.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/data_list.dart';
import '../../../../../core/widgets/file_upload_box.dart';
import '../../../../../core/widgets/panel_section.dart';
import '../../../../../core/widgets/stat_card.dart';
import '../../../domain/entities/geometry.dart';
import '../../controllers/contour_controller.dart';
import '../../controllers/display_settings_controller.dart';

/// Which statistic card was tapped (reference `setShowStatDetails`).
enum StatKind { boreholes, breaklines, triangles, contours }

/// Contents of the "≡ Data" tab (reference lines 3292–3367).
class DataTab extends StatelessWidget {
  const DataTab({this.onStatTap, super.key});

  final ValueChanged<StatKind>? onStatTap;

  @override
  Widget build(BuildContext context) {
    final hasPoints = context.select<ContourController, bool>(
      (c) => c.points.isNotEmpty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ImportSection(),
        _StatisticsSection(onStatTap: onStatTap),
        if (hasPoints) const _BoreholesSection(),
      ],
    );
  }
}

class _ImportSection extends StatelessWidget {
  const _ImportSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ContourController>();
    return PanelSection(
      title: 'Import Data',
      children: [
        FileUploadBox(
          icon: '📁',
          text: 'Click to upload Excel file',
          hint: '.xlsx format only',
          onTap: () => unawaited(controller.importSpreadsheet()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                small: true,
                expand: true,
                onPressed: controller.loadSample,
                child: const Text('📋 Sample'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                small: true,
                expand: true,
                variant: AppButtonVariant.danger,
                onPressed: controller.clear,
                child: const Text('🗑 Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection({this.onStatTap});

  final ValueChanged<StatKind>? onStatTap;

  VoidCallback? _tap(StatKind kind) =>
      onStatTap == null ? null : () => onStatTap!(kind);

  @override
  Widget build(BuildContext context) {
    final counts = context.select<ContourController, (int, int, int, int)>(
      (c) => (
        c.points.length,
        c.breakLines.length,
        c.model.triangles.length,
        c.model.contours.length,
      ),
    );
    return PanelSection(
      title: 'Statistics',
      children: [
        _grid([
          StatCard(
            value: '${counts.$1}',
            label: 'Boreholes',
            color: AppColors.accentCyan,
            onTap: _tap(StatKind.boreholes),
          ),
          StatCard(
            value: '${counts.$2}',
            label: 'Breaklines',
            color: AppColors.accentOrange,
            onTap: _tap(StatKind.breaklines),
          ),
          StatCard(
            value: '${counts.$3}',
            label: 'Triangles',
            color: AppColors.accentPurple,
            onTap: _tap(StatKind.triangles),
          ),
          StatCard(
            value: '${counts.$4}',
            label: 'Contours',
            color: AppColors.accentGreen,
            onTap: _tap(StatKind.contours),
          ),
        ]),
        const _RlRange(),
      ],
    );
  }

  /// `.stats-grid`: two equal columns, 8px gaps.
  Widget _grid(List<Widget> cards) => Column(
    children: [
      for (var i = 0; i < cards.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 8),
              Expanded(child: cards[i + 1]),
            ],
          ),
        ),
      ],
    ],
  );
}

class _RlRange extends StatelessWidget {
  const _RlRange();

  @override
  Widget build(BuildContext context) {
    final points = context.select<ContourController, List<SurveyPoint>>(
      (c) => c.points,
    );
    if (points.isEmpty) return const SizedBox.shrink();
    var lo = points.first.z;
    var hi = lo;
    for (final p in points) {
      if (p.z < lo) lo = p.z;
      if (p.z > hi) hi = p.z;
    }
    if (lo.isNaN || hi.isNaN) return const SizedBox.shrink();
    final base = AppText.ui(12, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'RL Range: '),
            TextSpan(
              text: lo.toFixed(2),
              style: base.copyWith(color: AppColors.accentCyan),
            ),
            const TextSpan(text: ' → '),
            TextSpan(
              text: hi.toFixed(2),
              style: base.copyWith(color: AppColors.accentGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoreholesSection extends StatelessWidget {
  const _BoreholesSection();

  static const int _collapsedCount = 10;

  @override
  Widget build(BuildContext context) {
    final points = context.select<ContourController, List<SurveyPoint>>(
      (c) => c.points,
    );
    final showAll = context.select<DisplaySettingsController, bool>(
      (d) => d.showAllBoreholes,
    );
    final display = context.read<DisplaySettingsController>();
    final visible = showAll ? points : points.take(_collapsedCount).toList();
    final extra = points.length - _collapsedCount;
    return PanelSection(
      title: 'Boreholes (${points.length})',
      children: [
        DataList(
          maxHeight: showAll ? null : 180,
          children: [
            for (final p in visible)
              DataItem(
                id: p.borehole,
                coords:
                    '${p.x.toFixed(1)}, ${p.y.toFixed(1)} → RL ${p.z.toFixed(2)}',
              ),
            if (extra > 0 && !showAll)
              DataItemAction(
                text: '+ $extra more... (click to expand)',
                onTap: () => display.showAllBoreholes = true,
              ),
            if (extra > 0 && showAll)
              DataItemAction(
                text: '▲ Show less',
                onTap: () => display.showAllBoreholes = false,
              ),
          ],
        ),
      ],
    );
  }
}
