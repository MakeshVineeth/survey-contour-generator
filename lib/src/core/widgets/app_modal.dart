import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Shows a modal route with the reference `.modal-overlay` barrier
/// (`rgba(0,0,0,0.7)`, tap to dismiss).
Future<T?> showAppModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: AppColors.modalBarrier,
  transitionDuration: Duration.zero,
  pageBuilder: (ctx, _, _) => builder(ctx),
);

/// `.modal`: rounded panel (width 90% up to [maxWidth], height up to 85vh)
/// with `.modal-header` (title + ×) and padded `.modal-body`.
class AppModal extends StatelessWidget {
  const AppModal({
    required this.title,
    required this.child,
    required this.onClose,
    this.maxWidth = 560,
    this.bodyMaxHeightFactor,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final double maxWidth;

  /// Extra scroll limit of the body as a fraction of the viewport height
  /// (the help modal uses `70vh`).
  final double? bodyMaxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(maxWidth, media.size.width * 0.9);
    final maxHeight = media.size.height * 0.85;
    final body = Padding(padding: const EdgeInsets.all(20), child: child);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Center(
          child: Container(
            width: width,
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModalHeader(title: title, onClose: onClose),
                  if (bodyMaxHeightFactor == null)
                    body
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: media.size.height * bodyMaxHeightFactor!,
                      ),
                      child: SingleChildScrollView(child: body),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(title, style: AppText.ui(16, weight: FontWeight.w600)),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Semantics(
            button: true,
            label: 'Close',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Text(
                '×',
                style: AppText.ui(
                  24,
                  color: AppColors.textSecondary,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
