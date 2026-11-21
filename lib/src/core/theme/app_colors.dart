import 'package:flutter/painting.dart';

/// Design tokens from the reference CSS `:root` (contour-v12_4-tin-fixed.html).
abstract final class AppColors {
  static const Color bgPrimary = Color(0xFF0A0E14);
  static const Color bgSecondary = Color(0xFF111820);
  static const Color bgTertiary = Color(0xFF1A2332);
  static const Color accentCyan = Color(0xFF00D9FF);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF00FF88);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentRed = Color(0xFFFF4757);
  static const Color accentYellow = Color(0xFFFFD93D);
  static const Color textPrimary = Color(0xFFE8EAED);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF5C6370);
  static const Color border = Color(0xFF2D3748);

  /// Translucent panel background used by overlays (rgba(17,24,32,0.95)).
  static const Color overlayPanel = Color(0xF2111820);

  // Second stops of the `.btn-*` gradients.
  static const Color cyanDark = Color(0xFF0099CC);
  static const Color orangeDark = Color(0xFFCC4400);
  static const Color greenDark = Color(0xFF00CC66);
  static const Color yellowDark = Color(0xFFFFB400);
  static const Color purpleDark = Color(0xFF7C3AED);

  /// Green of the `.xlsx` export tile (`#22c55e`).
  static const Color excelGreen = Color(0xFF22C55E);

  /// `rgba(0,0,0,0.7)` behind modals.
  static const Color modalBarrier = Color(0xB3000000);

  /// `rgba(0,0,0,0.5)` behind the mobile sidebar.
  static const Color drawerBarrier = Color(0x80000000);

  /// `linear-gradient(135deg, cyan, purple)` used by the logo and sliders.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentCyan, accentPurple],
  );
}

/// Font families bundled in pubspec.yaml.
abstract final class AppFonts {
  /// UI text (CSS `'Outfit', sans-serif`).
  static const String ui = 'Outfit';

  /// Numbers, inputs and coordinates (CSS `'JetBrains Mono', monospace`).
  static const String mono = 'JetBrainsMono';

  /// Bundled glyph fallbacks (emoji + symbols) so web renders without a CDN font.
  static const List<String> fallback = <String>[
    'NotoColorEmoji',
    'NotoSansSymbols2',
    'NotoSansSymbols',
    'NotoSansMath',
    'NotoSansJP',
  ];
}

/// Responsive breakpoint from the reference CSS (`@media (max-width: 768px)`).
abstract final class AppBreakpoints {
  static const double mobileMaxWidth = 768;
}
