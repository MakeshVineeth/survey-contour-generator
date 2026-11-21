import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// `.panel-section` with an optional `.panel-title`.
class PanelSection extends StatelessWidget {
  const PanelSection({required this.children, this.title, super.key});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [if (title != null) PanelTitle(title!), ...children],
    ),
  );
}

/// `.panel-title`: uppercase 11px label followed by a 1px rule.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: AppText.ui(
              11,
              color: AppColors.textMuted,
              weight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppColors.border),
          ),
        ),
      ],
    ),
  );
}

/// `.input-group` + `.input-label`.
class InputGroup extends StatelessWidget {
  const InputGroup({required this.label, required this.children, super.key});

  final Widget label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: label),
        ...children,
      ],
    ),
  );
}

/// Plain `.input-label` text.
class InputLabel extends StatelessWidget {
  const InputLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.ui(12, color: AppColors.textSecondary));
}
