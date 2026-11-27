# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [13.0.1] - 2026-11-27

### Fixed
- Touch: in Add Point mode a tap adds a point, a drag pans and two fingers pinch-zoom; zoom and pan no longer reset when the toolbar re-wraps.
- The orange draw-mode pill is a button that switches between Add Point and Pan/Zoom; tapping it or the legend no longer adds a point.
- Dialog close (x) and chart expand buttons, and small list buttons on phones, have touch-sized hit areas.

### Changed
- Faster startup and lower memory: Delaunay, contour chaining and label placement are O(n log n)-class with output identical to before (verified by equivalence tests); ThemeData built once; Android baseline profile.
- Web: the service worker installs after the app is on screen, which halves the cold-load time on slow links.
- Export dialog paths (PNG, BMP, Print, Excel, cancelled and failed saves) are covered by tests.

## [13.0.0]

### Changed
- Ported the single-file React app (v12.4) to Flutter. Targets: Android, Web (offline-capable PWA), Windows.
- Contour, TIN (Delaunay), terrain analysis and CAD exporters (DXF, AutoLISP, Civil 3D script) are pure Dart and
  verified against the JavaScript reference with parity fixtures.
- Map, TIN visualizer and charts are drawn with `CustomPainter` (replaces Highcharts and Anime.js).
- Excel import/export uses the `excel` package; only `.xlsx` is supported.
- Web build uses Wasm, bundled CanvasKit (`--no-web-resources-cdn`) and a custom service worker for offline use.
- Android release hardening: no INTERNET permission, backups disabled, cleartext traffic disabled, no debug-signing fallback.

### Fixed
- Coordinate or RL values of exactly `0` are no longer dropped on import.
- Borehole/line labels are sanitized in CAD exports to prevent AutoLISP/script injection.

### Removed
- "Make Offline" button, modal and badge, and the CDN boot/progress screen (all assets are now bundled).
- Runtime dependency on CDN-hosted libraries (React, Babel, SheetJS, Highcharts, Anime.js).

## [12.4.0] - 2026-01-26
- Last release of the single-file React/HTML application.
