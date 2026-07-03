# AGENTS.md — instructions for coding agents

This repository is an OSS SwiftUI library (working name: `swift-scoped-animation`,
module `ScopedAnimation`). **`HANDOFF.md` is the single source of truth for product
scope, API design, and roadmap. Read it before writing any code.**

## Ground rules

- Do not change public API, semantics, or roadmap phases unilaterally. If you
  believe the design in `HANDOFF.md` is wrong or infeasible, stop and report with
  evidence (spike code + findings) instead of silently deviating. Then update
  `HANDOFF.md` in the same PR once agreed.
- Phase order is mandatory. Phase 0 (spike, see HANDOFF §8) gates everything:
  if S1–S3 fail, stop and report. Do not start Phase 1 on top of unverified
  assumptions.
- Never report tests as passing without pasting the actual `swift test` /
  `xcodebuild test` output. If something is untestable, say so explicitly.
- Zero external dependencies in `Package.swift`. This is a product requirement.
- All user-facing text (README, DocC, doc comments, error messages) in English.
  Commit messages in English, imperative mood.

## Toolchain & targets

- Xcode 26.x / Swift 6.3, Swift 6 language mode, strict concurrency = complete.
- Platforms: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+.
- SwiftPM only. No CocoaPods, no Carthage.

## Build & test

```sh
swift build
swift test                          # macOS host tests
# iOS simulator (required before claiming Phase 1 items done):
xcodebuild test -scheme ScopedAnimation \
  -destination 'platform=iOS Simulator,name=iPhone 17' | tail -50
```

If the simulator name above does not exist on this machine, list devices with
`xcrun simctl list devices available` and pick the newest iPhone. Record the one
you used in the PR description.

## Code style

- swift-format with the repo's `.swift-format` config (create it in Phase 1;
  default style, 100-column line length). CI enforces `swift format lint`.
- Public API: 100% DocC doc comments, with a short code example on every public
  type. No `///` boilerplate that restates the signature.
- `#if DEBUG` guards for all diagnostics code paths; RELEASE builds must compile
  them out entirely (verify with `swift build -c release`).
- No force unwraps / force casts in library code. `fatalError` only for
  programmer-error preconditions, with an actionable message.
- Follow SwiftUI naming conventions: view modifiers as `View` extensions
  returning `some View`, containers as `struct ... : View`.

## Testing conventions

- Framework: Swift Testing (`import Testing`), not XCTest, unless hosting
  requirements force XCTest for a specific case — document why if so.
- The transaction-spy harness (HANDOFF §9) lives in `Tests/.../Support/`.
  Every core semantic (barrier, value-driven scope, stamping, leak detection)
  needs at least one spy-based behavioral test, not just unit tests of helpers.
- Flaky tests are bugs: no `sleep`-based waits; pump the run loop or use
  explicit expectations.

## CI (Phase 1 deliverable)

GitHub Actions on a macOS runner with Xcode 26.x:
build + test (macOS and iOS Simulator), `swift format lint`, DocC build
(`swift package generate-documentation`), release-config build. Verify the
runner image and Xcode version actually available on GitHub-hosted runners
before pinning — do not guess.

## Definition of done (per PR)

1. Builds warning-free under strict concurrency; tests pass locally (logs pasted).
2. New public API documented in DocC and exercised in the example app.
3. `CHANGELOG.md` updated under `Unreleased`.
4. No TODO/FIXME left without a linked issue reference.
