import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_info.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../controllers/contour_controller.dart';
import 'logo_mark.dart';

/// Reference `<header className="header">`: logo, title and the help/export
/// actions. [compact] is the `max-width: 768px` layout (menu button, icons
/// only).
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.compact,
    required this.onMenu,
    required this.onHelp,
    required this.onExport,
    super.key,
  });

  final bool compact;
  final VoidCallback onMenu;
  final VoidCallback onHelp;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        (compact ? 12 : 16) + inset.left,
        (compact ? 10 : 12) + inset.top,
        (compact ? 12 : 16) + inset.right,
        compact ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: _Logo(compact: compact, onMenu: onMenu),
          ),
          const SizedBox(width: 8),
          _Actions(compact: compact, onHelp: onHelp, onExport: onExport),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.compact, required this.onMenu});

  final bool compact;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (compact) ...[_MenuButton(onTap: onMenu), const SizedBox(width: 10)],
      const LogoMark(),
      const SizedBox(width: 10),
      Flexible(
        child: Text.rich(
          TextSpan(
            style: AppText.ui(16, weight: FontWeight.w600),
            children: [
              const TextSpan(text: 'Contour'),
              TextSpan(
                text: 'Gen',
                style: AppText.ui(
                  16,
                  color: AppColors.accentCyan,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 16),
        Text(
          'v${AppInfo.version}',
          style: AppText.ui(9, color: AppColors.textMuted),
        ),
      ],
    ],
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Semantics(
      button: true,
      label: 'Menu',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bgTertiary,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('☰', style: AppText.ui(18, height: 1)),
        ),
      ),
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.compact,
    required this.onHelp,
    required this.onExport,
  });

  final bool compact;
  final VoidCallback onHelp;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final hasPoints = context.select<ContourController, bool>(
      (c) => c.points.isNotEmpty,
    );
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : null;
    final minWidth = compact ? 44.0 : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          onPressed: onHelp,
          padding: padding,
          minWidth: minWidth,
          child: const Text('?'),
        ),
        SizedBox(width: compact ? 6 : 8),
        AppButton(
          variant: AppButtonVariant.export,
          semanticLabel: 'Export',
          onPressed: hasPoints ? onExport : null,
          padding: padding,
          minWidth: minWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📤'),
              if (!compact) ...[const SizedBox(width: 6), const Text('Export')],
            ],
          ),
        ),
      ],
    );
  }
}
