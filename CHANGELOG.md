# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

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
