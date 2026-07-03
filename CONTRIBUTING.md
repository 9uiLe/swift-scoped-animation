# Contributing

Thanks for working on ScopedAnimation.

## Source of Truth

`HANDOFF.md` is the design source of truth. Do not change public API, semantics, or roadmap phase order without updating the design and explaining the reason in the pull request.

## Requirements

- Xcode 26.x / Swift 6
- SwiftPM only
- Zero external dependencies
- Swift 6 language mode
- Strict concurrency enabled

## Local Checks

Run these before opening a pull request:

```sh
swift format lint --configuration .swift-format \
  Package.swift \
  Sources/ScopedAnimation/*.swift \
  Sources/ScopedAnimation/Diagnostics/*.swift \
  Tests/ScopedAnimationTests/*.swift \
  Tests/ScopedAnimationTests/Support/*.swift \
  Examples/ScopedAnimationExample/ScopedAnimationExample/*.swift

swift build
swift test
xcodebuild test -scheme ScopedAnimation -destination 'platform=iOS Simulator,name=iPhone 17'
swift build -c release
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS'
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

If `iPhone 17` is unavailable, use the newest available iPhone simulator and record the device name.

## Documentation

Public API needs DocC comments. User-facing documentation must be in English and must describe the model as blocking + detection, not total animation containment.

## Diagnostics

Diagnostics code paths must be guarded with `#if DEBUG`. When checking that code is absent from RELEASE artifacts, use a positive DEBUG control and inspect binaries with `strings` or `nm`.

## Tests

Behavioral transaction tests live in `Tests/ScopedAnimationTests/Support/`. Prefer spy-based tests for transaction semantics.
