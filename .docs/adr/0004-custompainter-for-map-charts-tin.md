# 4. CustomPainter for the map, charts and TIN animation

Status: Accepted

## Context
The reference draws the map on a canvas, charts with Highcharts and the TIN construction with Anime.js.
Charts must look like the reference and work on every target, including Wasm web.

## Decision
Draw the map (`MapPainter`, `MapExportPainter`), the slope/elevation charts and the TIN visualizer with
`CustomPainter`. No chart or animation packages are used. Chart math lives in plain Dart
(`chart_math.dart`, `map_geometry.dart`) so it can be unit tested. PNG/BMP export reuses the painter to
render a 3000x3000 px image.

## Consequences
- Full control of appearance and fewer dependencies to maintain.
- Tooltips, legends and hit testing are implemented by hand.
- Painters must stay cheap (`shouldRepaint`, cached geometry) for large point sets.
