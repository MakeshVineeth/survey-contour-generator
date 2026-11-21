# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

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
