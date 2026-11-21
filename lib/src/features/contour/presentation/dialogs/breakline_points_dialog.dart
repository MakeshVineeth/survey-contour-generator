import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/js_number.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input_field.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../domain/entities/geometry.dart';
import '../controllers/contour_controller.dart';

/// Opens the `<name> - Edit Points` modal for breakline [index].
Future<void> showBreaklinePointsDialog(BuildContext context, int index) =>
    showAppModal<void>(
      context,
      builder: (_) => BreaklinePointsDialog(index: index),
    );

/// Reference breakline points modal (lines 3967–4010).
class BreaklinePointsDialog extends StatelessWidget {
  const BreaklinePointsDialog({required this.index, super.key});

  final int index;

  void _close(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final line = context.select<ContourController, BreakLine?>(
      (c) => index < c.breakLines.length ? c.breakLines[index] : null,
    );
    if (line == null) {
      // The breakline vanished (deleted) while open: close like the reference.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _close(context);
      });
      return const SizedBox.shrink();
    }
    return AppModal(
      title: '${line.name} - Edit Points',
      maxWidth: 600,
      onClose: () => _close(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Summary(count: line.points.length),
          _PointsList(index: index, points: line.points),
          const SizedBox(height: 12),
          AppButton(
            variant: AppButtonVariant.success,
            expand: true,
            onPressed: () {
              context.read<ContourController>().announceBreakLinePointsSaved();
              _close(context);
            },
            child: const Text('✓ Done'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text.rich(
          TextSpan(
            style: AppText.ui(12, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Total Points: '),
              TextSpan(
                text: '$count',
                style: AppText.ui(
                  12,
                  color: AppColors.accentCyan,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Edit values, press Tab or click outside to save',
            textAlign: TextAlign.right,
            style: AppText.ui(10, color: AppColors.textMuted),
          ),
        ),
      ],
    ),
  );
}

class _PointsList extends StatelessWidget {
  const _PointsList({required this.index, required this.points});

  final int index;
  final List<Point3> points;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 400),
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(6),
    ),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ColumnHeader(),
          for (var i = 0; i < points.length; i++)
            BreaklinePointEditor(
              key: ValueKey('$index-$i'),
              breakLineIndex: index,
              pointIndex: i,
              point: points[i],
            ),
        ],
      ),
    ),
  );
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppText.ui(
      9,
      color: AppColors.textMuted,
      weight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 35, child: Text('#', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('X (Easting)', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('Y (Northing)', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('RL (Elevation)', style: style)),
        ],
      ),
    );
  }
}

/// One editable vertex row (reference `BreaklinePointEditor`): values commit
/// when a field loses focus or Enter is pressed; invalid numbers revert.
class BreaklinePointEditor extends StatefulWidget {
  const BreaklinePointEditor({
    required this.breakLineIndex,
    required this.pointIndex,
    required this.point,
    super.key,
  });

  final int breakLineIndex;
  final int pointIndex;
  final Point3 point;

  @override
  State<BreaklinePointEditor> createState() => _BreaklinePointEditorState();
}

enum _Axis { x, y, z }

class _BreaklinePointEditorState extends State<BreaklinePointEditor> {
  late final ContourController _contours;
  late final Map<_Axis, TextEditingController> _text;
  late final Map<_Axis, FocusNode> _focus;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _contours = context.read<ContourController>();
    _text = {
      for (final a in _Axis.values)
        a: TextEditingController(text: _valueOf(widget.point, a).toFixed(3)),
    };
    _focus = {
      for (final a in _Axis.values) a: FocusNode()..addListener(_onFocusChange),
    };
  }

  @override
  void dispose() {
    _closing = true;
    // Unsaved text is committed when the dialog closes (the browser blurs the
    // input first); deferred because the tree is locked during dispose.
    final pending = _pendingPoint();
    if (pending != null) {
      final target = (widget.breakLineIndex, widget.pointIndex);
      scheduleMicrotask(
        () => _contours.updateBreakLinePoint(target.$1, target.$2, pending),
      );
    }
    for (final n in _focus.values) {
      n.dispose();
    }
    for (final t in _text.values) {
      t.dispose();
    }
    super.dispose();
  }

  static double _valueOf(Point3 p, _Axis a) => switch (a) {
    _Axis.x => p.x,
    _Axis.y => p.y,
    _Axis.z => p.z,
  };

  void _onFocusChange() {
    if (_closing || _focus.values.any((n) => n.hasFocus)) return;
    _commit();
  }

  /// Reference `handleBlur`: valid numbers update the breakline, anything
  /// else restores the stored value.
  void _commit() {
    final next = _pendingPoint();
    if (next != null) {
      _contours.updateBreakLinePoint(
        widget.breakLineIndex,
        widget.pointIndex,
        next,
      );
    }
    final current = _currentPoint();
    for (final a in _Axis.values) {
      if (double.tryParse(_text[a]!.text) == null) {
        _text[a]!.text = _valueOf(current, a).toFixed(3);
      }
    }
  }

  /// The point with every valid field applied, or null when nothing changed.
  Point3? _pendingPoint() {
    final current = _currentPoint();
    double pick(_Axis a) {
      final parsed = double.tryParse(_text[a]!.text);
      return parsed != null && parsed.isFinite ? parsed : _valueOf(current, a);
    }

    final next = Point3(pick(_Axis.x), pick(_Axis.y), pick(_Axis.z));
    final same =
        next.x == current.x && next.y == current.y && next.z == current.z;
    return same ? null : next;
  }

  Point3 _currentPoint() {
    final lines = _contours.breakLines;
    if (widget.breakLineIndex >= lines.length) return widget.point;
    final pts = lines[widget.breakLineIndex].points;
    return widget.pointIndex < pts.length
        ? pts[widget.pointIndex]
        : widget.point;
  }

  Widget _field(_Axis axis, {Color color = AppColors.textPrimary}) => Expanded(
    child: AppInputField(
      compact: true,
      controller: _text[axis]!,
      focusNode: _focus[axis],
      textColor: color,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: const [DecimalInputFormatter()],
      onEditingComplete: _commit,
      semanticLabel: '${axis.name.toUpperCase()} #${widget.pointIndex + 1}',
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 35,
          child: Text(
            '#${widget.pointIndex + 1}',
            style: AppText.ui(
              11,
              color: AppColors.accentPurple,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _field(_Axis.x),
        const SizedBox(width: 8),
        _field(_Axis.y),
        const SizedBox(width: 8),
        _field(_Axis.z, color: AppColors.accentGreen),
      ],
    ),
  );
}
