import 'package:material_ui/material_ui.dart';

import 'core/theme/app_info.dart';
import 'core/theme/app_theme.dart';
import 'features/contour/presentation/screens/home_screen.dart';
import 'features/contour/presentation/widgets/shell/file_loading_overlay.dart';
import 'features/contour/presentation/widgets/shell/toast_overlay.dart';

/// Root widget: theme, home screen and the toast / file-loading overlays,
/// which sit above every route (including modals), like the reference's
/// `z-index` 1000 / 500.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [?child, const FileLoadingOverlay(), const ToastOverlay()],
      ),
    );
  }
}
