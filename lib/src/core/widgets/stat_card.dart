import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// `.stat-card`: value + uppercase caption, hover lift with cyan border.
class StatCard extends StatefulWidget {
  const StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
    super.key,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final lifted = _hover && !_down;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, lifted ? -2 : 0, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hover
                ? AppColors.accentCyan.withAlpha(0x0D)
                : AppColors.bgTertiary,
            border: Border.all(
              color: _hover ? AppColors.accentCyan : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: lifted
                ? [
                    BoxShadow(
                      color: AppColors.accentCyan.withAlpha(0x26),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.value,
                style: AppText.mono(
                  18,
                  color: widget.color,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppText.ui(
                  9,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
