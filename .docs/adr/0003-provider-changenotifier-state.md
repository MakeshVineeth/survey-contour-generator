# 3. Provider + ChangeNotifier for state management

Status: Accepted

## Context
State is modest: survey data, generated contours, display settings, draw mode and map viewport. The
project wants few dependencies and no business logic in widgets.

## Decision
Use `ChangeNotifier` controllers (`ContourController`, `DisplaySettingsController`, `DrawController`,
`MapViewController`) exposed with `provider`. Widgets rebuild narrowly with `context.select`,
`Selector` or `Consumer`. Controllers depend on domain services and on platform ports, which are
replaced by fakes in tests (`test/helpers/fakes.dart`).

## Consequences
- Few dependencies; controllers are easy to unit test.
- Discipline is required to keep rebuilds narrow and to dispose controllers and listeners.
- Replacing the state library later affects only the presentation layer.
