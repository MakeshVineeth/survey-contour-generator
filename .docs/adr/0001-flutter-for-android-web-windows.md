# 1. Flutter for Android, Web and Windows with a platform-agnostic core

Status: Accepted

## Context
The product was a single HTML file using React, Babel, SheetJS, Highcharts and Anime.js loaded from CDNs.
It needed to run as an Android app, an installable offline web app and a Windows app, with one UI that
customers already know and one set of contour algorithms.

## Decision
Use Flutter (Dart 3) with one shared codebase for Android, Web and Windows. All code is platform-agnostic;
platform differences (file save/pick, print, compute) live behind small interfaces in
`lib/src/core/platform/` with conditional-import adapters (`dart.library.io` / `dart.library.js_interop`).
`Platform.isX` checks are not used in UI code.

## Consequences
- One UI and one algorithm implementation for all targets.
- The UI must be re-created in Flutter widgets and painters to match the reference.
- Web cannot use isolates; heavy work goes through a `ComputeRunner` abstraction.
- The project follows the Flutter beta SDK pinned in `pubspec.yaml`.
