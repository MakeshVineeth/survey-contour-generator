import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../controllers/contour_controller.dart';

/// Reference `.toast`: bottom-centre green pill bound to
/// [ContourController.toast].
class ToastOverlay extends StatelessWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final message = context.select<ContourController, String?>((c) => c.toast);
    if (message == null) return const SizedBox.shrink();
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24 + bottom,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _SlideUp(child: _ToastBubble(message: message)),
        ),
      ),
    );
  }
}

/// `@keyframes slideUp`: from 20px below, transparent, over 0.3s ease.
class _SlideUp extends StatelessWidget {
  const _SlideUp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: const Duration(milliseconds: 300),
    curve: Curves.ease,
    child: child,
    builder: (_, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
    ),
  );
}

class _ToastBubble extends StatelessWidget {
  const _ToastBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border.all(color: AppColors.accentGreen),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGreen.withAlpha(0x33),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppText.ui(
          14,
          color: AppColors.accentGreen,
          weight: FontWeight.w500,
        ),
      ),
    ),
  );
}
