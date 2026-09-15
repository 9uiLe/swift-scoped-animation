# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Changed

- Prepare releases through a versioned-document PR and publish with local owner
  authentication only after the exact master commit passes package and
  release-tooling CI.
- Publish annotated `vX.Y.Z` tags and immutable, source-only GitHub Releases
  with validated recovery from interrupted publication.
- Run CI for every master push, including release-document changes, and disable
  persisted checkout credentials.
- Document the complete product contract, architecture, performance model, and
  validation procedure for new contributors.
- Resolve trigger history with one comparison pass and defer DEBUG warning
  formatting until after the debounce decision.
- Add reproducible DEBUG and RELEASE microbenchmarks for trigger resolution,
  construction, expensive value equality, and suppressed conflict warnings.
- Separate scope composition, value resolution, and transaction boundaries; share
  the strip-then-restore implementation between scopes and standalone barriers.
- Keep trigger values and animation configuration in one snapshot, pair selected
  indices with animations, and compile rejected-trigger storage out of RELEASE.
- Isolate trigger history to the main actor and centralize diagnostic site keys.
- Fail CI and release verification on formatting warnings with strict linting.
- Organize behavioral tests by contract under a serialized Swift Testing suite,
  retain and close every hosting window, reject empty transaction observations,
  and compare animation values directly.
- Cover sequential and disabled updates, both transition directions, trigger
  resizing and type changes, and the root detector's implicit-animation blind spot.

### Fixed

- Distinguish concrete trigger value types after type erasure, including `Int`
  versus `Optional<Int>` values that Swift can otherwise cast to each other.
- Prevent overlapping List QA runs and cancel pending checks when leaving the
  screen without publishing partial results.
- Hide decorative DEBUG scope outlines from accessibility navigation.

## 0.2.1 - 2026-07-15

### Fixed

- Select CI simulators by UDID from `simctl` JSON so device names containing
  parentheses cannot be truncated into invalid destinations.
- Preserve scoped content identity when a multi-trigger array changes between
  one, two, or more entries, and avoid the previous DEBUG out-of-bounds failure
  on trigger-count changes.
- Resolve simultaneous trigger changes explicitly by array position and use the
  same result for animation, stamping, and conflict diagnostics.
- Attribute nested value-driven updates to the inner scope even when its
  animation is equal to the ancestor animation.

### Changed

- Make `detectAnimationLeaks()` a structural no-op in RELEASE builds and audit
  release objects for diagnostic symbols and strings in CI.
- Bound DEBUG warning debounce storage, expire stale entries, and use stable
  warning-kind plus scope-name keys across view remounts.
- Derive each DEBUG overlay boundary color once per preference value instead of
  repeating the UUID reduction during overlay rendering.
- Remove per-transaction observable updates and actor tasks from List QA rows;
  publish only begin and finish snapshots to the status UI, and isolate the
  list behind narrow value inputs.
- Record the How / What / Why / Why Not information-placement policy in the
  repository agent instructions.

### Documentation

- Document empty, reordered, and dynamically resized trigger arrays and the
  single-resolver implementation model.
- Clarify the correct Instruments template for physical devices, the host Mac,
  and the iOS Simulator.

## 0.2.0 - 2026-07-05

- Add multi-trigger `AnimationScope(name:triggers:)` with declaration-order conflict resolution and DEBUG `multiTriggerConflict` warnings.
- Document nested scope semantics, composition patterns, static lint recipe, and small-app adoption guidance.
- Add DEBUG runtime warning when an AnimationScope boundary strips another scope's stamped animation.
- Add the GitHub social preview asset.
- Add scripts/release.sh to automate the release flow (checks, tests, changelog rollover, tag, GitHub release).
- CI: cancel superseded PR runs, cache SwiftPM/DerivedData build artifacts, and disable index-store generation in xcodebuild steps to cut run time.

## 0.1.0 - 2026-07-03

- Add `AnimationScope` value-driven and proxy-driven APIs.
- Add README demo GIF recordings from the example app screens.
- Add `animationBarrier(warnsOnLeaks:)` for stripping incoming animation.
- Add transaction stamping and strip-then-restore boundary semantics.
- Add DEBUG leak detection with runtime warnings and debounce.
- Add DEBUG scope overlay.
- Add transaction spy behavioral tests for core semantics.
- Add iOS example app with Before / After, overlay, and List QA screens.
- Add DocC documentation, README, CI, MIT license, and contribution guide.
