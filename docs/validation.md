# Validation results

- Recorded date: **2026-09-16**
- Toolchain: Xcode 26.5 (17F42), Apple Swift 6.3.2, Swift 6 language mode
- Host: Apple M1 Pro, macOS 26.2 (25C56)
- Simulator: iPhone 17, iOS 26.5,
  UDID `5A6604DB-0328-4DFD-89EF-6A5EEE0CE974`

The outputs below record an execution of the library validation suite.
The source was an uncommitted working tree; no release or commit is certified
by these results. Coverage is limited to the stated environment. Full local logs are in
`/tmp/scoped-animation-performance-20260916/`; command excerpts are retained here.

## Coverage

Hosted transaction tests cover incoming animation stripping, proxy stamp routing,
value-driven ownership, nested scopes, multi-trigger priority, structural count
changes, disabled updates, sequential updates, transitions, and diagnostic
placement. Pure tests cover concrete value types, selection, stamp identity,
and bounded debounce behavior.

A custom-animation description probe checks that suppressed warnings do not
format animation descriptions. RELEASE tests and the binary marker audit check
that diagnostic implementation is excluded from production artifacts.

See [SwiftUI assumptions](swiftui-assumptions.md) for the framework contracts
and [CONTRIBUTING.md](../CONTRIBUTING.md) for the maintained check commands.

## macOS DEBUG

```sh
swift build
swift test
```

Actual output excerpts:

```text
Build complete! (0.19s)
􁁛  Test run with 55 tests in 12 suites passed after 28.894 seconds.
```

## iOS Simulator

```sh
xcodebuild test -scheme ScopedAnimation \
  -destination 'platform=iOS Simulator,id=5A6604DB-0328-4DFD-89EF-6A5EEE0CE974' \
  -derivedDataPath /tmp/scoped-animation-refactor-dd COMPILER_INDEX_STORE_ENABLE=NO
```

Actual output excerpts:

```text
✔ Test run with 55 tests in 12 suites passed after 29.966 seconds.
** TEST SUCCEEDED **
```

## macOS RELEASE and diagnostic audit

```sh
swift build -c release
swift test -c release
bash scripts/verify-release-diagnostics.sh
```

Actual output excerpts:

```text
Build complete! (1.02s)
􁁛  Test run with 38 tests in 9 suites passed after 21.368 seconds.
Verified: DEBUG markers are present and RELEASE diagnostics are absent.
```

## Documentation, example, and static checks

```sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/scoped-animation-docs-dd COMPILER_INDEX_STORE_ENABLE=NO
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,id=5A6604DB-0328-4DFD-89EF-6A5EEE0CE974' \
  -derivedDataPath /tmp/scoped-animation-example-dd COMPILER_INDEX_STORE_ENABLE=NO
swift format lint --strict --recursive Sources Tests Benchmarks \
  Examples/ScopedAnimationExample/ScopedAnimationExample Package.swift
bash -n scripts/benchmark-performance.sh scripts/verify-release-diagnostics.sh scripts/release.sh
git diff --check
```

Actual Xcode output excerpts:

```text
** BUILD DOCUMENTATION SUCCEEDED **
** BUILD SUCCEEDED **
```

Formatting, shell syntax, and whitespace checks exited 0 with no output. No Swift
compiler warnings appeared. Xcode's App Intents processor emitted the
“Metadata extraction skipped. No AppIntents.framework dependency found.” warning
for the test runner and example app. DocC completed without warnings.

## Unverified areas

- No manual QA result is recorded for the source state tested here. The dated
  observations in [Examples/QA.md](../Examples/QA.md) apply to their stated run.
- Tests inspect supplied transactions, not intermediate rendered frames.
- Physical iOS, tvOS, watchOS, and visionOS devices were not exercised.
- Frame-rate, allocation, and energy measurements are outside this validation.
