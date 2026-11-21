import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/utils/js_number.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/data_list.dart';
import '../../../../../core/widgets/panel_section.dart';
import '../../../domain/entities/geometry.dart';
import '../../controllers/contour_controller.dart';
import '../../controllers/draw_controller.dart';
import '../../dialogs/breakline_points_dialog.dart';

/// Contents of the "✎ Draw" tab (reference lines 3440–3539).
class DrawTab extends StatelessWidget {
  const DrawTab({super.key});

  @override
  Widget build(BuildContext context) {
    final drawing = context.select<DrawController, bool>((d) => d.drawMode);
    final hasCurrent = context.select<DrawController, bool>(
      (d) => d.currentBreakline.isNotEmpty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ManualDrawing(),
        if (hasCurrent && drawing) const _CurrentPoints(),
        const _SavedBreaklines(),
      ],
    );
  }
}

class _ManualDrawing extends StatelessWidget {
  const _ManualDrawing();

  @override
  Widget build(BuildContext context) {
    final drawing = context.select<DrawController, bool>((d) => d.drawMode);
    return PanelSection(
      title: 'Manual Breakline Drawing',
      children: [
        const _HowToDraw(),
        if (drawing) const _DrawingActive() else const _StartButton(),
      ],
    );
  }
}

class _HowToDraw extends StatelessWidget {
  const _HowToDraw();

  @override
  Widget build(BuildContext context) {
    final style = AppText.ui(11, color: AppColors.textSecondary);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentCyan.withAlpha(0x1A),
        border: Border.all(color: AppColors.accentCyan.withAlpha(0x33)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '📋 How to Draw',
              style: AppText.ui(
                11,
                color: AppColors.accentCyan,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Text('1. Click "Start Drawing" below', style: style),
          Text('2. Click points on the canvas', style: style),
          Text('3. RL is auto-extrapolated from terrain', style: style),
          Text('4. Click "Finish" when done (min 2 pts)', style: style),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final hasPoints = context.select<ContourController, bool>(
      (c) => c.points.isNotEmpty,
    );
    return AppButton(
      variant: AppButtonVariant.primary,
      expand: true,
      onPressed: hasPoints
          ? context.read<DrawController>().toggleDrawMode
          : null,
      child: const Text('Start Drawing Breakline'),
    );
  }
}

class _DrawingActive extends StatelessWidget {
  const _DrawingActive();

  @override
  Widget build(BuildContext context) {
    final draw = context.read<DrawController>();
    final count = context.select<DrawController, int>(
      (d) => d.currentBreakline.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ActiveCard(),
        Row(
          children: [
            Expanded(
              child: AppButton(
                small: true,
                expand: true,
                variant: AppButtonVariant.success,
                onPressed: count >= 2 ? draw.toggleDrawMode : null,
                child: Text(
                  '✓ Finish (${count >= 2 ? '✓' : 'need ${2 - count}'})',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                small: true,
                expand: true,
                onPressed: count > 0 ? draw.undoLastPoint : null,
                child: const Text('↩ Undo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppButton(
          small: true,
          expand: true,
          variant: AppButtonVariant.danger,
          onPressed: draw.cancelDraw,
          child: const Text('✕ Cancel Drawing'),
        ),
      ],
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard();

  @override
  Widget build(BuildContext context) {
    final line = context.select<DrawController, List<Point3>>(
      (d) => d.currentBreakline,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withAlpha(0x26),
        border: Border.all(color: AppColors.accentOrange.withAlpha(0x4D)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '● Drawing Mode Active',
            style: AppText.ui(
              13,
              color: AppColors.accentOrange,
              weight: FontWeight.w600,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Click anywhere on the canvas to add points',
              style: AppText.ui(11, color: AppColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '📍 ${line.length} point${line.length != 1 ? 's' : ''} added',
              style: AppText.ui(
                14,
                color: AppColors.accentYellow,
                weight: FontWeight.w600,
              ),
            ),
          ),
          if (line.isNotEmpty) _LastPoint(point: line.last),
        ],
      ),
    );
  }
}

class _LastPoint extends StatelessWidget {
  const _LastPoint({required this.point});

  final Point3 point;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0x33000000),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Last Point:',
            style: AppText.ui(10, color: AppColors.textMuted),
          ),
        ),
        Text(
          'X: ${point.x.toFixed(2)} | Y: ${point.y.toFixed(2)}',
          style: AppText.mono(11),
        ),
        Text.rich(
          TextSpan(
            style: AppText.mono(
              12,
              color: AppColors.accentGreen,
              weight: FontWeight.w600,
            ),
            children: [
              TextSpan(text: 'RL: ${point.z.toFixed(2)} m '),
              TextSpan(
                text: '(extrapolated)',
                style: AppText.ui(9, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CurrentPoints extends StatelessWidget {
  const _CurrentPoints();

  @override
  Widget build(BuildContext context) {
    final line = context.select<DrawController, List<Point3>>(
      (d) => d.currentBreakline,
    );
    return PanelSection(
      title: 'Current Breakline Points',
      children: [
        DataList(
          maxHeight: 150,
          children: [
            for (var i = 0; i < line.length; i++)
              DataItem(
                id: 'P${i + 1}',
                idColor: AppColors.accentOrange,
                coords:
                    '${line[i].x.toFixed(1)}, ${line[i].y.toFixed(1)} → RL ${line[i].z.toFixed(2)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _SavedBreaklines extends StatelessWidget {
  const _SavedBreaklines();

  @override
  Widget build(BuildContext context) {
    final lines = context.select<ContourController, List<BreakLine>>(
      (c) => c.breakLines,
    );
    return PanelSection(
      title: 'Saved Breaklines (${lines.length})',
      children: [
        if (lines.isEmpty) const _NoBreaklines() else _BreaklineList(lines),
      ],
    );
  }
}

class _NoBreaklines extends StatelessWidget {
  const _NoBreaklines();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Text('📐', style: AppText.ui(24)),
        const SizedBox(height: 8),
        Text(
          'No breaklines yet. Draw one above!',
          textAlign: TextAlign.center,
          style: AppText.ui(12, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _BreaklineList extends StatelessWidget {
  const _BreaklineList(this.lines);

  final List<BreakLine> lines;

  @override
  Widget build(BuildContext context) {
    final contours = context.read<ContourController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataList(
          maxHeight: 200,
          children: [
            for (var i = 0; i < lines.length; i++)
              _BreaklineRow(index: i, line: lines[i]),
          ],
        ),
        const SizedBox(height: 10),
        AppButton(
          small: true,
          expand: true,
          variant: AppButtonVariant.success,
          onPressed: () => unawaited(contours.exportBreaklinesXlsx()),
          child: const Text('📊 Export All to Excel'),
        ),
        const SizedBox(height: 8),
        AppButton(
          small: true,
          expand: true,
          variant: AppButtonVariant.purple,
          onPressed: () => unawaited(contours.exportAutoLisp()),
          child: const Text('📝 Export AutoLISP Script'),
        ),
      ],
    );
  }
}

class _BreaklineRow extends StatelessWidget {
  const _BreaklineRow({required this.index, required this.line});

  final int index;
  final BreakLine line;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                style: AppText.ui(
                  12,
                  color: AppColors.accentCyan,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${line.points.length} points',
                style: AppText.mono(10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        AppButton(
          small: true,
          semanticLabel: 'View & Edit points',
          onPressed: () => unawaited(showBreaklinePointsDialog(context, index)),
          child: const Text('✏️ Edit'),
        ),
        const SizedBox(width: 6),
        AppButton(
          small: true,
          variant: AppButtonVariant.danger,
          semanticLabel: 'Delete',
          onPressed: () =>
              context.read<ContourController>().deleteBreakLine(index),
          child: const Text('×'),
        ),
      ],
    ),
  );
}
