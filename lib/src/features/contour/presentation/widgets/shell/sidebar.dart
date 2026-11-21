import 'package:material_ui/material_ui.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text.dart';
import '../analysis/analysis_tab.dart';
import '../panels/data_tab.dart';
import '../panels/draw_tab.dart';
import '../panels/layers_tab.dart';
import '../panels/settings_tab.dart';

/// Sidebar tabs in reference order.
enum SidebarTab {
  data('≡ Data'),
  settings('⚙ Settings'),
  draw('✎ Draw'),
  analysis('◔ Analysis'),
  layers('☰ Layers');

  const SidebarTab(this.label);

  final String label;
}

/// Reference `<aside className="sidebar">`: tab strip + scrolling content.
class Sidebar extends StatelessWidget {
  const Sidebar({
    required this.active,
    required this.onSelect,
    required this.compact,
    this.onStatTap,
    super.key,
  });

  final SidebarTab active;
  final ValueChanged<SidebarTab> onSelect;

  /// Mobile layout (10.5px tab labels, safe-area padding for the drawer).
  final bool compact;

  /// Opens the statistics details dialog (owned by the analysis feature).
  final ValueChanged<StatKind>? onStatTap;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context);
    return Container(
      padding: compact
          ? EdgeInsets.only(top: inset.top, bottom: inset.bottom)
          : EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabStrip(active: active, onSelect: onSelect, compact: compact),
          Expanded(
            child: _SidebarContent(tab: active, onStatTap: onStatTap),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.active,
    required this.onSelect,
    required this.compact,
  });

  final SidebarTab active;
  final ValueChanged<SidebarTab> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        for (final tab in SidebarTab.values)
          Expanded(
            child: _TabButton(
              tab: tab,
              selected: tab == active,
              compact: compact,
              onTap: () => onSelect(tab),
            ),
          ),
      ],
    ),
  );
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final SidebarTab tab;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hover = false;

  Color get _color {
    if (widget.selected) return AppColors.accentCyan;
    return _hover ? AppColors.textPrimary : AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 3 : 6,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: _hover && !widget.selected
                ? AppColors.bgTertiary
                : const Color(0x00000000),
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: widget.selected
                    ? AppColors.accentCyan
                    : const Color(0x00000000),
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.tab.label,
              maxLines: 1,
              softWrap: false,
              style: AppText.ui(
                widget.compact ? 10.5 : 11,
                color: _color,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({required this.tab, this.onStatTap});

  final SidebarTab tab;
  final ValueChanged<StatKind>? onStatTap;

  @override
  Widget build(BuildContext context) => Scrollbar(
    child: SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(16),
      child: switch (tab) {
        SidebarTab.data => DataTab(onStatTap: onStatTap),
        SidebarTab.settings => const SettingsTab(),
        SidebarTab.draw => const DrawTab(),
        SidebarTab.analysis => const AnalysisTab(),
        SidebarTab.layers => const LayersTab(),
      },
    ),
  );
}
