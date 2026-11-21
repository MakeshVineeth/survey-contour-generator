import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/core/platform/compute_runner.dart';
import 'src/core/platform/file_service.dart';
import 'src/core/platform/print_service.dart';
import 'src/features/contour/presentation/controllers/contour_controller.dart';
import 'src/features/contour/presentation/controllers/display_settings_controller.dart';
import 'src/features/contour/presentation/controllers/draw_controller.dart';
import 'src/features/contour/presentation/controllers/map_view_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ContourController>(
          create: (_) => ContourController(
            files: createFileService(),
            printer: const PrintingPrintService(),
            runner: createComputeRunner(),
          ),
        ),
        ChangeNotifierProvider<DisplaySettingsController>(
          create: (_) => DisplaySettingsController(),
        ),
        ChangeNotifierProvider<DrawController>(
          lazy: false,
          create: _createDrawController,
        ),
        // After DrawController: chains onto its `onDataReset` hook.
        ChangeNotifierProvider<MapViewController>(
          lazy: false,
          create: (ctx) => MapViewController(ctx.read<ContourController>()),
        ),
      ],
      child: const App(),
    ),
  );
}

DrawController _createDrawController(BuildContext context) {
  final contours = context.read<ContourController>();
  final display = context.read<DisplaySettingsController>();
  final draw = DrawController(contours);
  contours.onDataReset = () {
    draw.cancelDraw();
    display.showAllBoreholes = false;
  };
  return draw;
}
