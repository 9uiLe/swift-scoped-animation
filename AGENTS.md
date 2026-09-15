# AGENTS.md — instructions for coding agents

This repository is the `swift-scoped-animation` OSS SwiftUI library,
module `ScopedAnimation`. **`HANDOFF.md` is the single source of truth for product
scope, API design, and roadmap. Read it before writing any code.**

## Ground rules

- Do not change public API, semantics, or roadmap phases unilaterally. If you
  believe the design in `HANDOFF.md` is wrong or infeasible, stop and report with
  evidence (spike code + findings) instead of silently deviating. Then update
  `HANDOFF.md` in the same PR once agreed.
- Follow the dependency order in HANDOFF §9. Boundary stripping, local
  restoration, and stamp propagation must be verified before dependent work.
  If those assumptions fail, stop and report a reproduction; do not silently
  change the design. See `docs/swiftui-assumptions.md` for the compatibility gates.
- Never report tests as passing without pasting the actual `swift test` /
  `xcodebuild test` output. If something is untestable, say so explicitly.
- Zero external dependencies in `Package.swift`. This is a product requirement.
- All user-facing text (README, DocC, doc comments, error messages) in English.
  Commit messages in English, imperative mood.

## Put information where it will live longest

- **Code owns How.** Express how the implementation works through names,
  types, and control flow. Do not add comments that merely narrate the code;
  rename or restructure the code instead.
- **Tests own What.** Treat tests as executable specifications. Test names,
  setup, and assertions must state the behavior the product promises.
- **Commit history owns Why.** Commit messages must preserve the motivation and
  context that made the change necessary, not just summarize the diff.
- **Implementation comments own Why Not.** Add a code comment only when a
  non-obvious constraint rules out the simpler implementation, or when a
  considered alternative was rejected for a reason the code cannot express.
  State that constraint or rejected alternative directly.

Required DocC comments are user-facing API documentation, not implementation
commentary: they describe the public contract and usage. Durable product and API
decisions continue to belong in `HANDOFF.md`.

## Toolchain & targets

- Xcode 26.x / Swift 6.3, Swift 6 language mode, strict concurrency = complete.
- Platforms: iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+.
- SwiftPM only. No CocoaPods, no Carthage.

## Build & test

```sh
swift build
swift test                          # macOS host tests
python3 -m unittest discover -s scripts/tests -v  # release tooling
# iOS simulator (required for core semantic changes):
xcodebuild test -scheme ScopedAnimation \
  -destination 'platform=iOS Simulator,name=iPhone 17' | tail -50
```

If the simulator name above does not exist on this machine, list devices with
`xcrun simctl list devices available` and pick the newest iPhone. Record the one
you used in the PR description.

## Code style

- Use the repo's `.swift-format` config: default style, 100-column line length.
  CI enforces `swift format lint --strict`.
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
- The transaction-spy harness (HANDOFF §8) lives in `Tests/.../Support/`.
  Every core semantic (barrier, value-driven scope, stamping, leak detection)
  needs at least one spy-based behavioral test, not just unit tests of helpers.
- Flaky tests are bugs: no `sleep`-based waits; pump the run loop or use
  explicit expectations.

## CI

GitHub Actions on a macOS runner with Xcode 26.x:
build + test (macOS and iOS Simulator), `swift format lint --strict`, DocC build
(`xcodebuild docbuild`), RELEASE build and tests, diagnostic symbol audit, and
example app build. Verify the runner image and Xcode version actually available
on GitHub-hosted runners before pinning — do not guess.

## Release tooling

- `docs/releasing.md` defines the local owner-authenticated release commands.
- Use Python standard-library `unittest` for `scripts/release.py`, with temporary
  Git repositories and simulated GitHub responses. Tests must not publish tags
  or Releases.
- CI remains read-only. Publication requires successful master push CI for the
  exact source commit, including package and release-tooling jobs.

## Definition of done (per PR)

1. Builds warning-free under strict concurrency; tests pass locally (logs pasted).
2. New public API documented in DocC and exercised in the example app.
3. `CHANGELOG.md` updated under `Unreleased`.
4. No TODO/FIXME left without a linked issue reference.
5. When adding or renaming DEBUG diagnostics, update the positive-control marker
   list in `scripts/verify-release-diagnostics.sh` so the RELEASE symbol audit
   covers the new diagnostic.
