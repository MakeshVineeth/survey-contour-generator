import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// `.input-field`: tertiary background, 1px border, cyan focus glow.
///
/// [compact] reproduces the inline style of the breakline point editor
/// (primary background, radius 4, 6x8 padding, 12px text, no glow).
class AppInputField extends StatefulWidget {
  const AppInputField({
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onEditingComplete,
    this.keyboardType,
    this.inputFormatters,
    this.compact = false,
    this.textColor = AppColors.textPrimary,
    this.semanticLabel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool compact;
  final Color textColor;
  final String? semanticLabel;

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  FocusNode? _ownNode;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AppInputField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (_focused != _node.hasFocus) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: compact ? AppColors.bgPrimary : AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(
          color: _focused ? AppColors.accentCyan : AppColors.border,
        ),
        boxShadow: _focused && !compact
            ? [
                BoxShadow(
                  color: AppColors.accentCyan.withAlpha(0x4D),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Semantics(
        label: widget.semanticLabel,
        textField: true,
        child: TextField(
          controller: widget.controller,
          focusNode: _node,
          style: AppText.mono(compact ? 12 : 13, color: widget.textColor),
          cursorColor: AppColors.accentCyan,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          maxLines: 1,
          decoration: const InputDecoration.collapsed(hintText: null),
        ),
      ),
    );
  }
}

/// Keeps only `-?digits[.digits]` (the keys the reference editor accepts).
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter();

  static final RegExp _allowed = RegExp(r'^-?\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _allowed.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Hint overlay helper kept next to the field (used by the settings tab).
class AppFieldHint extends StatelessWidget {
  const AppFieldHint({required this.text, this.size = 11, super.key});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: AppText.ui(size, color: AppColors.textMuted)),
  );
}
