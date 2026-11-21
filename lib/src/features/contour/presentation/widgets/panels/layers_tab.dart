import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/widgets/checkbox_group.dart';
import '../../../../../core/widgets/panel_section.dart';
import '../../controllers/display_settings_controller.dart';

/// Contents of the "☰ Layers" tab (reference lines 3653–3699).
class LayersTab extends StatelessWidget {
  const LayersTab({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_DisplayLayers(), _Legend(), _DxfLayers()],
  );
}

class _DisplayLayers extends StatelessWidget {
  const _DisplayLayers();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DisplaySettingsController>();
    return PanelSection(
      title: 'Display Layers',
      children: [
        CheckboxGroup(
          value: d.showTIN,
          label: '🔺 TIN Mesh',
          onChanged: (v) => d.showTIN = v,
        ),
        CheckboxGroup(
          value: d.showContours,
          label: '〰️ Contour Lines',
          onChanged: (v) => d.showContours = v,
        ),
        CheckboxGroup(
          value: d.showBreakLines,
          label: '📐 Manual Breaklines',
          onChanged: (v) => d.showBreakLines = v,
        ),
        CheckboxGroup(
          value: d.showLabels,
          label: '🏷 Labels & RL Values',
          onChanged: (v) => d.showLabels = v,
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => PanelSection(
    title: 'Legend',
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgTertiary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem('Borehole Points', Color(0xFF00D9FF), dot: true),
            _LegendItem('Manual Breaklines', Color(0xFFFF6B35)),
            _LegendItem('Minor Contours', Color(0xFF00FF88)),
            _LegendItem('Major Contours', Color(0xFFFF4757)),
            _LegendItem('TIN Mesh', Color(0x806366F1)),
          ],
        ),
      ),
    ],
  );
}

/// `.legend-item` with a `.legend-dot` (8px circle) or `.legend-color`
/// (16x3 bar).
class _LegendItem extends StatelessWidget {
  const _LegendItem(this.label, this.color, {this.dot = false});

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(
          width: dot ? 8 : 16,
          height: dot ? 8 : 3,
          decoration: BoxDecoration(
            color: color,
            shape: dot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: dot ? null : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppText.ui(11)),
      ],
    ),
  );
}

class _DxfLayers extends StatelessWidget {
  const _DxfLayers();

  static const List<String> _layers = [
    '• BOREHOLES (Green)',
    '• BH-LABELS (White)',
    '• RL-LABELS (Cyan)',
    '• BREAKLINES (Magenta)',
    '• CONTOURS (Yellow)',
    '• CONTOURS-MAJOR (Red)',
    '• TIN (Gray)',
  ];

  @override
  Widget build(BuildContext context) => PanelSection(
    title: 'DXF Layers',
    children: [
      for (final layer in _layers)
        Text(layer, style: AppText.mono(10, color: AppColors.textMuted)),
    ],
  );
}
