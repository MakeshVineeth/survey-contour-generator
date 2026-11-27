import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Visual variants of the reference `.btn-*` classes.
enum AppButtonVariant {
  primary,
  secondary,
  danger,
  export,
  success,
  yellow,
  purple,
}

/// `.btn`: radius 6, gradient fills, hover lift + glow.
class AppButton extends StatefulWidget {
  const AppButton({
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.small = false,
    this.expand = false,
    this.padding,
    this.minWidth,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// `.btn-sm`.
  final bool small;

  /// Fill the available width (`width: 100%` / `flex: 1`).
  final bool expand;
  final EdgeInsetsGeometry? padding;
  final double? minWidth;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final style = _ButtonStyle.of(widget.variant);
    // Phone-width screens: the small in-list buttons (Edit, x) get a 40 px
    // minimum so a thumb hits them; desktop keeps the compact look.
    final compactTouch = widget.small && MediaQuery.sizeOf(context).width < 600;
    final lifted = _hover && _enabled && style.lifts;
    final padding =
        widget.padding ??
        (widget.small
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10));
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
      constraints: BoxConstraints(
        minWidth: widget.minWidth ?? (compactTouch ? 40 : 0),
        minHeight: compactTouch ? 40 : 0,
      ),
      padding: padding,
      decoration: style.decoration(hover: _hover && _enabled),
      child: DefaultTextStyle(
        style: AppText.ui(
          widget.small ? 12 : 13,
          color: style.foreground,
          weight: style.weight,
        ),
        textAlign: TextAlign.center,
        child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
      ),
    );
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: box)
              : box,
        ),
      ),
    );
  }
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.foreground,
    this.gradient,
    this.fill,
    this.hoverFill,
    this.border,
    this.glow,
    this.glowBlur = 15,
    this.weight = FontWeight.w500,
    this.lifts = true,
  });

  final Color foreground;
  final Gradient? gradient;
  final Color? fill;
  final Color? hoverFill;
  final Color? border;
  final Color? glow;
  final double glowBlur;
  final FontWeight weight;
  final bool lifts;

  static LinearGradient _g(Color a, Color b) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [a, b],
  );

  static _ButtonStyle of(AppButtonVariant v) => switch (v) {
    AppButtonVariant.primary => _ButtonStyle(
      foreground: AppColors.bgPrimary,
      gradient: _g(AppColors.accentCyan, AppColors.cyanDark),
      glow: AppColors.accentCyan.withAlpha(0x4D),
      glowBlur: 20,
    ),
    AppButtonVariant.secondary => const _ButtonStyle(
      foreground: AppColors.textPrimary,
      fill: AppColors.bgTertiary,
      hoverFill: AppColors.border,
      border: AppColors.border,
      lifts: false,
    ),
    AppButtonVariant.danger => _ButtonStyle(
      foreground: AppColors.accentRed,
      fill: AppColors.accentRed.withAlpha(0x26),
      border: AppColors.accentRed.withAlpha(0x4D),
      lifts: false,
    ),
    AppButtonVariant.export => _ButtonStyle(
      foreground: const Color(0xFFFFFFFF),
      gradient: _g(AppColors.accentOrange, AppColors.orangeDark),
      glow: AppColors.accentOrange.withAlpha(0x4D),
    ),
    AppButtonVariant.success => _ButtonStyle(
      foreground: AppColors.bgPrimary,
      gradient: _g(AppColors.accentGreen, AppColors.greenDark),
      glow: AppColors.accentGreen.withAlpha(0x66),
    ),
    AppButtonVariant.yellow => _ButtonStyle(
      foreground: AppColors.bgPrimary,
      gradient: _g(AppColors.accentYellow, AppColors.yellowDark),
      glow: AppColors.accentYellow.withAlpha(0x66),
      weight: FontWeight.w600,
    ),
    AppButtonVariant.purple => _ButtonStyle(
      foreground: const Color(0xFFFFFFFF),
      gradient: _g(AppColors.accentPurple, AppColors.purpleDark),
      glow: AppColors.accentPurple.withAlpha(0x66),
    ),
  };

  BoxDecoration decoration({required bool hover}) => BoxDecoration(
    gradient: gradient,
    color: gradient == null ? (hover ? hoverFill ?? fill : fill) : null,
    borderRadius: BorderRadius.circular(6),
    border: border == null ? null : Border.all(color: border!),
    boxShadow: hover && glow != null
        ? [BoxShadow(color: glow!, blurRadius: glowBlur)]
        : null,
  );
}
