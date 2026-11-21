# 2. Feature-first Clean Architecture with a pure-Dart domain and JS parity tests

Status: Accepted

## Context
The contour/TIN/analysis/export algorithms are the product's value and must behave like the validated
JavaScript reference. They must be testable without a UI or a device.

## Decision
Layout: `lib/src/features/contour/{domain,data,presentation}` plus `lib/src/core`.
`domain/` (entities, services) is pure Dart: no Flutter, `dart:ui`, `dart:html`, `dart:io` or plugins.
`test/architecture/domain_isolation_test.dart` enforces this.
Algorithm behaviour is pinned by `test/fixtures/parity.json`, generated from the reference HTML by
`node tool/gen_parity_fixtures.js contour-v12_4-tin-fixed.html test/fixtures/parity.json`, and checked by
`test/features/contour/domain/parity_test.dart`.

## Consequences
- Domain code runs in isolates, on web and in plain Dart tests without changes.
- Algorithm changes must keep parity tests green; intentional deviations (e.g. zero-value import) are documented.
- Regenerating fixtures needs Node.js and the reference HTML.
