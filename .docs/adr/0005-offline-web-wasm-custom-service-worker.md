# 5. Offline web via Wasm, bundled CanvasKit and a custom service worker

Status: Accepted

## Context
The web app must work offline after the first visit (surveyors work in the field). Flutter's built-in
service worker is deprecated, and by default the engine (CanvasKit) is fetched from a CDN.

## Decision
Build with `flutter build web --release --wasm --no-web-resources-cdn --web-content-hash`.
CanvasKit is then served from the app's own origin. `web/sw.js` is a hand-written service worker:
it precaches every entry of `precache_manifest.json` (except `canvaskit/**`) in a per-build cache,
serves hashed assets cache-first and `index.html`/bootstrap/manifest network-first, caches only the
CanvasKit variant the browser actually loads, and deletes old-build caches on activate.
A failed install removes its partial cache so the previous build keeps working.
`web/manifest.json` makes the app installable.

## Consequences
- No network is needed after the first load; an update applies once the new build has been cached.
- We own the service worker and must test install failure, update and offline reload.
- Wasm requires a modern browser; the engine files increase the first download.
