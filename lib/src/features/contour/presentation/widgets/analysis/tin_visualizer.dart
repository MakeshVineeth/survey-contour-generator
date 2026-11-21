import 'package:material_ui/material_ui.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/geometry.dart';
import '../../../domain/entities/triangle.dart';
import '../../painters/tin_visualizer_painter.dart';
import '../../painters/viz_style.dart';
import 'analysis_cards.dart';

enum _TinState { idle, playing, complete }

/// "△ TIN Construction Visualizer" (reference `TINVisualizer`, lines
/// 1372–1650): Animate/Replay/Reset controls, canvas, legend and counters.
class TinVisualizer extends StatefulWidget {
  const TinVisualizer({
    required this.points,
    required this.triangles,
    required this.breakLines,
    this.isExpanded = false,
    this.onExpand,
    super.key,
  });

  final List<SurveyPoint> points;
  final List<Triangle> triangles;
  final List<BreakLine> breakLines;
  final bool isExpanded;
  final VoidCallback? onExpand;

  @override
  State<TinVisualizer> createState() => _TinVisualizerState();
}

class _TinVisualizerState extends State<TinVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  _TinState _state = _TinState.idle;
  TinVisualData? _data;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(TinVisualizer old) {
    super.didUpdateWidget(old);
    final changed =
        !identical(old.triangles, widget.triangles) ||
        !identical(old.points, widget.points) ||
        !identical(old.breakLines, widget.breakLines) ||
        old.isExpanded != widget.isExpanded;
    if (changed) {
      _controller.stop();
      _data = null;
      _state = _TinState.idle;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _state == _TinState.playing) {
      setState(() => _state = _TinState.complete);
    }
  }

  void _play() {
    final data = _data;
    if (data == null) return;
    _controller.duration = Duration(milliseconds: data.timeline.totalMs.ceil());
    setState(() => _state = _TinState.playing);
    _controller.forward(from: 0);
  }

  void _reset() {
    _controller.stop();
    setState(() => _state = _TinState.idle);
  }

  TinVisualData _dataFor(Size size) {
    final current = _data;
    if (current != null && current.size == size) return current;
    return _data = TinVisualData(
      points: widget.points,
      triangles: widget.triangles,
      breakLines: widget.breakLines,
      size: size,
      expanded: widget.isExpanded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgTertiary, Color(0x0800D9FF)],
        ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Header(),
                _Controls(state: _state, onPlay: _play, onReset: _reset),
                _canvas(context),
                const _Legend(),
                _Counters(
                  points: widget.points.length,
                  triangles: widget.triangles.length,
                  breakLines: widget.breakLines.length,
                ),
                const _Footer(),
              ],
            ),
          ),
          if (widget.onExpand != null)
            Positioned(
              top: 8,
              right: 8,
              child: ExpandButton(
                tooltip: 'Expand TIN visualization',
                onTap: widget.onExpand!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _canvas(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppBreakpoints.mobileMaxWidth;
    final height = widget.isExpanded ? 400.0 : (mobile ? 220.0 : 280.0);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LayoutBuilder(
          builder: (context, c) {
            final data = _dataFor(Size(c.maxWidth, c.maxHeight));
            return RepaintBoundary(
              child: CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: TinVisualizerPainter(
                  data: data,
                  animation: _state == _TinState.idle ? null : _controller,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Keep the badge clear of the corner "↗" expand button.
          padding: const EdgeInsets.only(bottom: 14, right: 36),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '△ TIN Construction Visualizer',
                  style: VizStyle.sans(
                    12,
                    AppColors.accentPurple,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'ANIME.JS',
                  style: VizStyle.sans(8, AppColors.accentPurple),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Watch how Delaunay triangulation builds the terrain mesh',
            style: VizStyle.sans(10, AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onPlay,
    required this.onReset,
  });

  final _TinState state;
  final VoidCallback onPlay;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      _TinState.idle => '▶ Animate',
      _TinState.playing => '● Playing...',
      _TinState.complete => '▶ Replay',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TinButton(
            label: label,
            active: state == _TinState.playing,
            onPressed: state == _TinState.playing ? null : onPlay,
          ),
          if (state != _TinState.idle) ...[
            const SizedBox(width: 8),
            _TinButton(label: '↺ Reset', onPressed: onReset),
          ],
        ],
      ),
    );
  }
}

class _TinButton extends StatefulWidget {
  const _TinButton({
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  State<_TinButton> createState() => _TinButtonState();
}

class _TinButtonState extends State<_TinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final active = widget.active;
    final Color bg;
    final Color fg;
    final Color border;
    if (active) {
      bg = AppColors.accentPurple;
      fg = const Color(0xFFFFFFFF);
      border = AppColors.accentPurple;
    } else {
      bg = enabled && _hover ? AppColors.border : AppColors.bgTertiary;
      fg = enabled && _hover ? AppColors.textPrimary : AppColors.textSecondary;
      border = AppColors.border;
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.label,
                style: VizStyle.sans(11, fg, weight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            const _LegendItem(
              color: AppColors.accentCyan,
              text: 'Survey Points',
            ),
            _LegendItem(
              color: AppColors.accentPurple.withValues(alpha: 0.6),
              text: 'Triangles',
            ),
            const _LegendItem(
              color: AppColors.accentOrange,
              text: 'Breaklines',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: VizStyle.sans(10, AppColors.textMuted)),
      ],
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({
    required this.points,
    required this.triangles,
    required this.breakLines,
  });

  final int points;
  final int triangles;
  final int breakLines;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppBreakpoints.mobileMaxWidth;
    final gap = mobile ? 6.0 : 8.0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          _box('$points', 'Points', AppColors.accentCyan, mobile),
          SizedBox(width: gap),
          _box('$triangles', 'Triangles', AppColors.accentPurple, mobile),
          SizedBox(width: gap),
          _box('$breakLines', 'Breaklines', AppColors.accentOrange, mobile),
        ],
      ),
    );
  }

  Widget _box(String value, String label, Color color, bool mobile) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                value,
                style: VizStyle.mono(
                  mobile ? 16 : 20,
                  color,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              label.toUpperCase(),
              style: VizStyle.sans(mobile ? 8 : 9, AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          'Advanced timeline • Elastic bouncing • Staggered morphing',
          textAlign: TextAlign.center,
          style: VizStyle.sans(9, AppColors.textMuted, height: 1.4),
        ),
      ),
    );
  }
}
