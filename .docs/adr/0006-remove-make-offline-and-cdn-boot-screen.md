# 6. Removal of the "Make Offline" feature and the CDN boot screen

Status: Accepted

## Context
The reference app loaded libraries from CDNs, showed a boot/progress screen while they loaded, and offered
a "Make Offline" button that inlined those libraries into a downloadable HTML file (plus
"Offline/Online version" badges and texts).

## Decision
Do not port these. All code and fonts are bundled in every target, so nothing is downloaded at runtime
and there is nothing to make offline. The CDN boot screen is replaced at most by a plain logo splash.
All other UI, copy and behaviour is kept as in the reference.

## Consequences
- Simpler UI and no offline-bundling code path.
- Users of the old HTML switch to the installable PWA, Android or Windows app for offline use.
- This is the only intentional UI deviation from the reference.
