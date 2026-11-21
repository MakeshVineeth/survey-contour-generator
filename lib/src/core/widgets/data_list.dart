import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// `.data-list`: bordered, rounded scroll box. Rows are separated by a 1px
/// rule except the last one (`:last-child`).
class DataList extends StatelessWidget {
  const DataList({required this.children, this.maxHeight, super.key});

  final List<Widget> children;

  /// `null` = `max-height: none`.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              border: i == children.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: children[i],
          ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxHeight: maxHeight ?? double.infinity),
      child: maxHeight == null ? column : SingleChildScrollView(child: column),
    );
  }
}

/// `.data-item`: id (cyan, 12px) above coordinates (secondary, 10px).
class DataItem extends StatelessWidget {
  const DataItem({
    required this.id,
    required this.coords,
    this.idColor = AppColors.accentCyan,
    super.key,
  });

  final String id;
  final String coords;
  final Color idColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          id,
          style: AppText.mono(12, color: idColor, weight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(coords, style: AppText.mono(10, color: AppColors.textSecondary)),
      ],
    ),
  );
}

/// Tappable `.data-item` used for "+ n more..." / "▲ Show less".
class DataItemAction extends StatelessWidget {
  const DataItemAction({required this.text, required this.onTap, super.key});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: AppText.mono(
            11,
            color: AppColors.accentCyan,
            weight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
