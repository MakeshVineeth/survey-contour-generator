import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../../controllers/contour_controller.dart';

/// Reference `.file-loading-overlay`, bound to
/// [ContourController.fileLoading]. Blocks input while an import runs.
class FileLoadingOverlay extends StatelessWidget {
  const FileLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<ContourController, FileLoadingState?>(
      (c) => c.fileLoading,
    );
    if (state == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: ColoredBox(
              color: const Color(0xF20A0E14),
              child: Material(
                type: MaterialType.transparency,
                child: Center(child: _Content(state: state)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final FileLoadingState state;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _BouncingIcon(),
      const SizedBox(height: 16),
      Text(
        'Loading Excel Data',
        style: AppText.ui(18, weight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(state.stage, style: AppText.ui(13, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      _ProgressBar(percent: state.progress),
    ],
  );
}

/// `@keyframes bounce` (1s, infinite): 0 -> -10px -> 0.
class _BouncingIcon extends StatefulWidget {
  const _BouncingIcon();

  @override
  State<_BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<_BouncingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) {
      final t = _controller.value;
      final lift = (t < 0.5 ? t : 1 - t) * 2;
      return Transform.translate(
        offset: Offset(0, -10 * Curves.ease.transform(lift)),
        child: child,
      );
    },
    child: Text('📊', style: AppText.ui(48, height: 1.2)),
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    height: 6,
    decoration: BoxDecoration(
      color: AppColors.bgTertiary,
      borderRadius: BorderRadius.circular(3),
    ),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.centerLeft,
    child: AnimatedFractionallySizedBox(
      duration: const Duration(milliseconds: 300),
      widthFactor: (percent / 100).clamp(0.0, 1.0),
      heightFactor: 1,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accentCyan, AppColors.accentGreen],
          ),
        ),
      ),
    ),
  );
}
