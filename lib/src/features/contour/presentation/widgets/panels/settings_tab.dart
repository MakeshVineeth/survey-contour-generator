import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/utils/js_number.dart';
import '../../../../../core/widgets/app_input_field.dart';
import '../../../../../core/widgets/app_slider.dart';
import '../../../../../core/widgets/panel_section.dart';
import '../../controllers/contour_controller.dart';

/// Contents of the "⚙ Settings" tab (reference lines 3369–3438).
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_ContourSettings(), _ExcelFormat()],
  );
}

class _ContourSettings extends StatefulWidget {
  const _ContourSettings();

  @override
  State<_ContourSettings> createState() => _ContourSettingsState();
}

class _ContourSettingsState extends State<_ContourSettings> {
  late final TextEditingController _interval;
  late final TextEditingController _major;
  final FocusNode _intervalFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final c = context.read<ContourController>();
    _interval = TextEditingController(text: _format(c.interval));
    _major = TextEditingController(text: '${c.majorEvery}');
    _intervalFocus.addListener(_onIntervalFocus);
  }

  @override
  void dispose() {
    _intervalFocus
      ..removeListener(_onIntervalFocus)
      ..dispose();
    _interval.dispose();
    _major.dispose();
    super.dispose();
  }

  /// JavaScript prints `1` for `1.0`.
  static String _format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _onIntervalChanged(String text) {
    final value = double.tryParse(text);
    if (value == null || value <= 0) return;
    context.read<ContourController>().setInterval(value);
  }

  /// Reference `onBlur`: an empty or invalid interval falls back to 1.0.
  void _onIntervalFocus() {
    if (_intervalFocus.hasFocus) return;
    final value = double.tryParse(_interval.text);
    if (value != null && value > 0) return;
    context.read<ContourController>().setInterval(1);
    _interval.text = _format(1);
  }

  /// `Math.max(1, parseInt(value) || 1)`, written back like a controlled input.
  void _onMajorChanged(String text) {
    final match = RegExp(r'^\s*[+-]?\d+').firstMatch(text);
    final parsed = match == null ? 1 : int.parse(match.group(0)!.trim());
    final value = parsed < 1 ? 1 : parsed;
    context.read<ContourController>().setMajorEvery(value);
    if (text != '$value') {
      _major.value = TextEditingValue(
        text: '$value',
        selection: TextSelection.collapsed(offset: '$value'.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PanelSection(
      title: 'Contour Settings',
      children: [
        InputGroup(
          label: const InputLabel('Contour Interval (m)'),
          children: [
            AppInputField(
              controller: _interval,
              focusNode: _intervalFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
              ],
              onChanged: _onIntervalChanged,
              semanticLabel: 'Contour Interval (m)',
            ),
          ],
        ),
        InputGroup(
          label: const InputLabel('Major Contour Every'),
          children: [
            AppInputField(
              controller: _major,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onMajorChanged,
              semanticLabel: 'Major Contour Every',
            ),
            const _MajorHint(),
          ],
        ),
        const _SmoothingGroup(),
      ],
    );
  }
}

class _MajorHint extends StatelessWidget {
  const _MajorHint();

  @override
  Widget build(BuildContext context) {
    final span = context.select<ContourController, double>(
      (c) => c.interval * c.majorEvery,
    );
    return AppFieldHint(text: 'Major every ${span.toFixed(1)}m');
  }
}

class _SmoothingGroup extends StatelessWidget {
  const _SmoothingGroup();

  @override
  Widget build(BuildContext context) {
    final value = context.select<ContourController, double>(
      (c) => c.smoothness,
    );
    return InputGroup(
      label: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const InputLabel('Smoothing'),
          Text(
            value.toFixed(1),
            style: AppText.mono(
              10,
              color: AppColors.accentCyan,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
      children: [
        AppSlider(
          value: value,
          min: ContourController.minSmoothness,
          max: ContourController.maxSmoothness,
          divisions: 20,
          semanticLabel: 'Smoothing',
          onChanged: context.read<ContourController>().setSmoothness,
        ),
        const AppFieldHint(text: '0 = Angular, 10 = Very smooth', size: 10),
      ],
    );
  }
}

class _ExcelFormat extends StatelessWidget {
  const _ExcelFormat();

  static const List<String> _required = [
    '• BoreholeID (or BH, ID, Name, Point)',
    '• X (or Easting, E)',
    '• Y (or Northing, N)',
    '• RL (or Z, Elevation, Elev)',
  ];
  static const List<String> _breaklines = [
    '• LineName (or BreakLine, Line)',
    '• X, Y, RL coordinates',
  ];

  @override
  Widget build(BuildContext context) => PanelSection(
    title: 'Excel Format',
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgTertiary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Required Columns:', AppColors.accentCyan, gap: 8),
            _lines(_required),
            const SizedBox(height: 10),
            _heading('For Breaklines:', AppColors.accentOrange),
            _lines(_breaklines),
          ],
        ),
      ),
    ],
  );

  Widget _heading(String text, Color color, {double gap = 0}) => Padding(
    padding: EdgeInsets.only(bottom: gap),
    child: Text(
      text,
      style: AppText.ui(11, color: color, weight: FontWeight.w600),
    ),
  );

  Widget _lines(List<String> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final l in lines)
        Text(l, style: AppText.mono(10, color: AppColors.textSecondary)),
    ],
  );
}
