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

## Large-screen set (foldable, desktop/Chromebook, 16:10 tablet, phone landscape)

Produced with the **release APK** (`build/app/outputs/flutter-apk/app-release.apk`) running on Android 14 (API 34,
google_apis_playstore, x86_64) emulators created at the exact Play-required resolution (no device frame, no scaling),
sample data loaded with the in-app "Sample" button, demo-mode status bar (10:00, full battery/Wi-Fi). Real device
screenshots (`adb screencap`), converted to 24-bit RGB (IHDR colour type 2); all well under 8 MB. The temporary AVDs
were deleted afterwards. These are emulator captures of the unmodified app, not Flutter test renders.

| File | Pixels | Ratio | Play Console slot | Density |
|---|---|---|---|---|
| `foldable/foldable-inner-1x1-01-map.png`, `-02-analysis.png` | 2106 x 2106 | 1:1 | Foldable, unfolded inner screen | 420 dpi |
| `foldable/foldable-inner-4x3-01-map.png`, `-02-data.png` | 2688 x 2016 | 4:3 | Foldable, unfolded inner screen | 420 dpi |
| `foldable/foldable-outer-10x16-01-map.png`, `-02-analysis.png` | 1260 x 2016 | 10:16 | Foldable, folded outer (cover) screen | 420 dpi |
| `desktop/desktop-01-map.png`, `-02-data.png`, `-03-analysis.png`, `-04-export.png` | 1920 x 1080 | 16:9 | Desktop / Chromebook | 320 dpi |
| `tablet-landscape/tablet-landscape-01-map.png`, `-02-data.png`, `-03-analysis.png`, `-04-export.png` | 2560 x 1600 | 16:10 | 7-inch and 10-inch tablet (landscape) | 420 dpi |
| `phone-landscape/phone-landscape-01-map.png`, `-02-analysis.png` | 1920 x 1080 | 16:9 | Phone, landscape (optional) | 420 dpi |

Layout notes: >= 768 dp wide windows (all but the 10:16 cover screen and the phone-landscape set) show sidebar + map;
the 10:16 and phone-landscape shots use the drawer layout (the Analysis shots show the drawer open).
