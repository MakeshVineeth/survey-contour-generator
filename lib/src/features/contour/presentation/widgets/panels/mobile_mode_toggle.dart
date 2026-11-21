import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../controllers/draw_controller.dart';

/// `.mobile-mode-toggle` ("➕ Add Point" / "🧭 Pan/Zoom"). In the reference it
/// lives in the canvas toolbar, so it is exposed for the canvas area to use;
/// it is not placed in the sidebar (that would be a new control).
class MobileModeToggle extends StatelessWidget {
  const MobileModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<DrawController, MobileDrawMode>(
      (d) => d.mobileDrawMode,
    );
    final draw = context.read<DrawController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeButton(
          label: '➕ Add Point',
          active: mode == MobileDrawMode.add,
          onTap: () => draw.setMobileDrawMode(MobileDrawMode.add),
        ),
        const SizedBox(width: 4),
        _ModeButton(
          label: '🧭 Pan/Zoom',
          active: mode == MobileDrawMode.navigate,
          onTap: () => draw.setMobileDrawMode(MobileDrawMode.navigate),
        ),
      ],
    );
  }
}

class _ModeButton extends StatefulWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.accentCyan : AppColors.bgTertiary,
              border: Border.all(
                width: 2,
                color: active ? AppColors.accentCyan : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.accentCyan.withAlpha(0x4D),
                        blurRadius: 15,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: AppText.ui(
                11,
                weight: FontWeight.w600,
                color: active ? AppColors.bgPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
