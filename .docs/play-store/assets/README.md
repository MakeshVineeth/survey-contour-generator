# Google Play store graphics

All images are generated from the repo (no manual editing). Screenshots are rendered from the real app UI with the
built-in sample data (`ContourController.loadSample()`) and the bundled fonts (Outfit, JetBrains Mono, Noto fallbacks).

PNG colour type: every screenshot and the feature graphic are **24-bit RGB, fully opaque** (IHDR colour type 2, as Play
requires). Only `icon-512.png` is **32-bit RGBA** (colour type 6); it is intentionally a full-bleed square (no rounded
corners, no shadow) because Play applies its own mask. All files are well under Play's 8 MB limit (largest ~0.6 MB).

| File | Pixels | Format | Play Console slot |
|---|---|---|---|
| `icon-512.png` | 512 x 512 | PNG, 32-bit RGBA | App icon |
| `feature-graphic-1024x500.png` | 1024 x 500 | PNG, 24-bit RGB | Feature graphic |
| `phone/01-map.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (raw, map + TIN + contours + labels + legend) |
| `phone/02-data.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (Data tab: import, statistics, boreholes) |
| `phone/03-analysis-tin.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (Analysis: TIN visualizer) |
| `phone/04-analysis-charts.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (elevation profile + slope donut) |
| `phone/05-export.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (Export dialog) |
| `phone/06-draw.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (draw mode, breakline in progress) |
| `phone-captioned/01..06-*.png` | 1080 x 1920 | PNG, 24-bit RGB | Phone screenshots (marketing variant: same six shots under a headline) |
| `tablet-7in/01-map.png`, `02-analysis.png`, `03-export.png` | 1200 x 1920 | PNG, 24-bit RGB | 7-inch tablet screenshots |
| `tablet-10in/01-map.png`, `02-analysis.png`, `03-export.png` | 1600 x 2560 | PNG, 24-bit RGB | 10-inch tablet screenshots |

Upload either the `phone/` set or the `phone-captioned/` set (same order); Play accepts 2-8 phone screenshots.

Captioned headlines (accent word in cyan): 1 "Contour maps in seconds", 2 "Import Excel survey data",
3 "Terrain analysis built in", 4 "Elevation and slope charts", 5 "Export to AutoCAD and more",
6 "Draw breaklines on the map".

Notes
- Phone shots render at 360x640 logical px, pixel ratio 3 (mobile layout, sidebar as drawer). The 7-inch set is
  600x960 logical at ratio 2 (still the mobile layout, the breakpoint is 768px); the 10-inch set is 800x1280 at ratio 2
  (desktop layout: sidebar + map). Map hero shots use a normal user zoom (1.3x on phone) so the survey fills the screen.
- The slope donut is 100% "Flat" because the built-in sample data is gentle terrain.

## Regenerate

Run from the repo root (PowerShell 7 `pwsh` for the first command; Windows PowerShell 5 is blocked by execution policy):

```
pwsh -NoProfile -File tool/store_assets/generate_graphics.ps1            # icon-512.png + feature graphic
flutter test tool/store_assets/capture_screenshots_test.dart             # phone/, phone-captioned/, tablet-7in/, tablet-10in/
```

Sources: `tool/store_assets/generate_graphics.ps1` and `tool/store_assets/capture_screenshots_test.dart`
(the test lives in `tool/`, so the normal `flutter test` never runs it). Verify with the PNG IHDR bytes
(width/height at offset 16, colour type at byte 25: 2 = RGB, 6 = RGBA).
