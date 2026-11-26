import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Dark theme matching the reference CSS (no splash, Outfit default font).
abstract final class AppTheme {
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarDividerColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  /// Built once and shared by `theme` / `darkTheme` (avoids rebuilding the
  /// full Material text theme more than once at startup).
  static final ThemeData dark = _buildDark();

  static ThemeData _buildDark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      canvasColor: AppColors.bgSecondary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentCyan,
        secondary: AppColors.accentPurple,
        surface: AppColors.bgSecondary,
        error: AppColors.accentRed,
        onPrimary: AppColors.bgPrimary,
        onSurface: AppColors.textPrimary,
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: const Color(0x00000000),
      highlightColor: const Color(0x00000000),
      hoverColor: const Color(0x00000000),
      focusColor: const Color(0x00000000),
      dividerColor: AppColors.border,
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll<double>(6),
        radius: Radius.circular(3),
        thumbColor: WidgetStatePropertyAll<Color>(AppColors.border),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accentCyan,
        selectionColor: AppColors.accentCyan.withAlpha(0x55),
        selectionHandleColor: AppColors.accentCyan,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppFonts.ui,
        fontFamilyFallback: AppFonts.fallback,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
