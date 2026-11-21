import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Text styles that never inherit (no stray letter spacing or decorations),
/// mirroring the reference's explicit `font-size` / `font-weight` rules.
abstract final class AppText {
  /// Outfit UI text.
  static TextStyle ui(
    double size, {
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? height,
    double letterSpacing = 0,
    TextDecoration? decoration,
  }) => TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: AppFonts.ui,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );

  /// JetBrains Mono numbers, inputs and coordinates.
  static TextStyle mono(
    double size, {
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: AppFonts.mono,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}
