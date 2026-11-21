import 'package:material_ui/material_ui.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/terrain.dart';
import '../../painters/viz_style.dart';

/// `.summary-card`: tertiary panel with a cyan title.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.title,
    required this.children,
    this.titleWidget,
    this.gradient = false,
    super.key,
  });

  final String title;

  /// Replaces the plain title text (e.g. title plus a pill).
  final Widget? titleWidget;
  final List<Widget> children;

  /// Cyan-tinted gradient background (AI summary card).
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gradient ? null : AppColors.bgTertiary,
        gradient: gradient
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bgTertiary, Color(0x0D00D9FF)],
              )
            : null,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child:
                titleWidget ??
                Text(
                  title,
                  style: VizStyle.sans(
                    12,
                    AppColors.accentCyan,
                    weight: FontWeight.w600,
                  ),
                ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// `.summary-item`: muted label on the left, monospace value on the right.
class SummaryItem extends StatelessWidget {
  const SummaryItem({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    super.key,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: VizStyle.sans(11, AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: VizStyle.mono(11, valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.terrain-badge`: 20 % tinted pill.
class TerrainBadge extends StatelessWidget {
  const TerrainBadge({required this.text, required this.color, super.key});

  /// Badge for a slope class or terrain type.
  factory TerrainBadge.forType(TerrainType type, {Key? key}) => TerrainBadge(
    key: key,
    text: '${type.name.toUpperCase()} TERRAIN',
    color: colorOf(type),
  );

  final String text;
  final Color color;

  static Color colorOf(TerrainType type) => switch (type) {
    TerrainType.flat => AppColors.accentGreen,
    TerrainType.gentle => AppColors.accentCyan,
    TerrainType.moderate => AppColors.accentYellow,
    TerrainType.steep => AppColors.accentOrange,
    TerrainType.extreme => AppColors.accentRed,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: VizStyle.sans(10, color, weight: FontWeight.w600),
      ),
    );
  }
}

/// `.chart-expand`: the "↗" button in the corner of a card.
class ExpandButton extends StatefulWidget {
  const ExpandButton({required this.tooltip, required this.onTap, super.key});

  final String tooltip;
  final VoidCallback onTap;

  @override
  State<ExpandButton> createState() => _ExpandButtonState();
}

class _ExpandButtonState extends State<ExpandButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _hover ? 1.1 : 1,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _hover
                      ? AppColors.accentCyan.withValues(alpha: 0.15)
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Opacity(
                  opacity: _hover ? 1 : 0.7,
                  child: Text(
                    '↗',
                    style: VizStyle.sans(18, AppColors.accentCyan),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.chart-container`: titled card around a chart.
class ChartContainer extends StatelessWidget {
  const ChartContainer({
    required this.title,
    required this.expandTooltip,
    required this.onExpand,
    required this.child,
    super.key,
  });

  final String title;
  final String expandTooltip;
  final VoidCallback onExpand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Keep long titles clear of the corner "↗" expand button.
                  padding: const EdgeInsets.only(bottom: 8, right: 32),
                  child: Text(
                    title,
                    style: VizStyle.sans(
                      12,
                      AppColors.accentCyan,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: ExpandButton(tooltip: expandTooltip, onTap: onExpand),
          ),
        ],
      ),
    );
  }
}
