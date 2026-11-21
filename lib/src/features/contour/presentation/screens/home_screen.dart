import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../dialogs/export_dialog.dart';
import '../dialogs/help_dialog.dart';
import '../dialogs/stat_details_dialog.dart';
import '../widgets/map/map_canvas_area.dart';
import '../widgets/panels/data_tab.dart';
import '../widgets/shell/app_background.dart';
import '../widgets/shell/app_header.dart';
import '../widgets/shell/sidebar.dart';

/// Reference `.app-container`: header, sidebar and canvas area. Below the
/// 768px breakpoint the sidebar becomes an overlay drawer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({this.onStatTap, super.key});

  /// Opens the statistics details dialog for a tapped stat card.
  final ValueChanged<StatKind>? onStatTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _drawerMaxWidth = 280;

  SidebarTab _tab = SidebarTab.data;
  bool _drawerOpen = false;

  void _setDrawer({required bool open}) {
    if (_drawerOpen != open) setState(() => _drawerOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= AppBreakpoints.mobileMaxWidth;
    final drawerOpen = compact && _drawerOpen;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: PopScope(
        canPop: !drawerOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _setDrawer(open: false);
        },
        child: Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: Stack(
            fit: StackFit.expand,
            children: [
              AppBackground(child: _page(compact)),
              if (compact) ..._drawer(width, drawerOpen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(bool compact) => Column(
    children: [
      AppHeader(
        compact: compact,
        onMenu: () => _setDrawer(open: true),
        onHelp: () => unawaited(showHelpDialog(context)),
        onExport: () => unawaited(showExportDialog(context)),
      ),
      Expanded(child: _main(compact)),
    ],
  );

  Widget _main(bool compact) {
    final inset = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.only(left: inset.left, right: inset.right),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) SizedBox(width: 320, child: _sidebar(compact)),
          const Expanded(child: MapCanvasArea()),
        ],
      ),
    );
  }

  Widget _sidebar(bool compact) => Sidebar(
    active: _tab,
    compact: compact,
    onStatTap:
        widget.onStatTap ?? (kind) => showStatDetailsDialog(context, kind),
    onSelect: (t) => setState(() => _tab = t),
  );

  /// `.sidebar-overlay` + fixed `.sidebar` (85% wide, max 280px, 0.3s slide).
  List<Widget> _drawer(double width, bool open) {
    final drawerWidth = math.min(width * 0.85, _drawerMaxWidth);
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _setDrawer(open: false),
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const ColoredBox(color: AppColors.drawerBarrier),
            ),
          ),
        ),
      ),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        top: 0,
        bottom: 0,
        left: open ? 0 : -drawerWidth,
        width: drawerWidth,
        child: ExcludeSemantics(excluding: !open, child: _sidebar(true)),
      ),
    ];
  }
}
