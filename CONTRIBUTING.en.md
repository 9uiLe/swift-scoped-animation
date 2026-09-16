# Contributing

[日本語](CONTRIBUTING.md) | English

Japanese is the primary language of this repository. This is the English edition.

Read the product contract, locate the behavior you are changing, and validate it
on the supported hosting environments.

## Source of Truth

`HANDOFF.md` is the design source of truth. Do not change public API, semantics, or roadmap phase order without updating the design and explaining the reason in the pull request.

## Repository Map

| Path | Responsibility |
| --- | --- |
| `Sources/ScopedAnimation/` | Scope composition, trigger resolution, boundaries, proxies, and stamps |
| `Sources/ScopedAnimation/Diagnostics/` | DEBUG warnings, leak detection, and overlays |
| `Sources/ScopedAnimation/Documentation.docc/` | Public API guides |
| `Tests/ScopedAnimationTests/` | Behavioral and pure contract tests |
| `Tests/ScopedAnimationTests/Support/` | Hosting, transaction recording, and test fixtures |
| `Examples/ScopedAnimationExample/` | Interactive iOS sample |
| `Examples/QA.md` | Manual QA procedure and environment-specific results |
| `Benchmarks/` | Internal CPU measurement fixtures and method |
| `docs/` | Compatibility assumptions, reference measurements, and validation evidence |

The [design](HANDOFF.md) defines each component's responsibility. The
[validation record](docs/validation.md) lists measured coverage and limitations.

## Requirements

- Xcode 26.x / Swift 6.3
- SwiftPM only
- Zero external dependencies
- Swift 6 language mode
- Strict concurrency enabled
- Python 3.10+ for release-tooling tests (standard library only)

## Local Checks

Run these before opening a pull request:

```sh
python3 -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh

swift format lint --strict --configuration .swift-format \
  Package.swift \
  Benchmarks/*.swift \
  Sources/ScopedAnimation/*.swift \
  Sources/ScopedAnimation/Diagnostics/*.swift \
  Tests/ScopedAnimationTests/*.swift \
  Tests/ScopedAnimationTests/Support/*.swift \
  Examples/ScopedAnimationExample/ScopedAnimationExample/*.swift

swift build
swift test
xcodebuild test -scheme ScopedAnimation -destination 'platform=iOS Simulator,name=iPhone 17'
swift build -c release
swift test -c release
bash scripts/verify-release-diagnostics.sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS'
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

If `iPhone 17` is unavailable, use the newest available iPhone simulator and record the device name.

## Documentation

Public API needs DocC comments. Describe the model as blocking and detection;
state changes and all animation are not confined to a scope.

## Language policy

- Japanese is the primary language for design documents, DocC, API and implementation
  comments, diagnostic/error messages, sample UI, issues, PRs, and commit messages.
  Commit messages must also explain the motivation for the change.
- Maintain English editions of README, CONTRIBUTING, SECURITY, and CODE_OF_CONDUCT
  with the `.en.md` suffix and reciprocal links. Update both editions in the same PR.
- Issues and PRs in English are welcome. Design and operating guides without an
  English edition use Japanese.
- Keep API/type/variable/file names, CLI subcommands, and machine-facing identifiers
  in English. Preserve required CI job names, CHANGELOG `## Unreleased` and version
  headings, and DocC syntax such as `Overview`, `Topics`, and `Parameter`.
- Keep execution logs, historical measurements, and external quotations verbatim.
  LICENSE contains the original English MIT license.
- Keep installation versions identical in both READMEs. Release commands update
  and validate both editions.

## Diagnostics

Diagnostics code paths must be guarded with `#if DEBUG`. When checking that code is absent from RELEASE artifacts, use a positive DEBUG control and inspect binaries with `strings` or `nm`.

## Tests

Behavioral tests are grouped by contract in `Tests/ScopedAnimationTests/`; their
hosting views, models, and transaction spy live in `Support/`.

Use Swift Testing. Add hosting and warning-capture tests under the serialized
`AnimationScopeBehaviorTests` suite so run-loop updates and the global warning
sink cannot overlap. Retain each host and close it with `defer`.

A negative animation assertion must first observe a transaction. The recorder
reports an issue for empty observations, and compares `Animation` values directly.
When asserting ownership, check the animation and stamp on the same recorded
transaction.
Keep pure tests independent of SwiftUI hosting when they exercise selection or
bounded debounce behavior.

## Performance Measurements

Run `bash scripts/benchmark-performance.sh release` and
`bash scripts/benchmark-performance.sh debug` sequentially with no concurrent
builds or simulator work. Follow [Benchmarks/README.md](Benchmarks/README.md).
Record compiler flags, environment, operation definitions, and raw timings.
Do not infer frame-rate or allocation improvements from internal CPU timings.

## Releasing

The owner uses local `scripts/release.py` commands to prepare a release PR,
verify the merged source commit, and publish its annotated tag and GitHub
Release. GitHub Actions validates commits with read-only permissions.

```sh
./scripts/release.py prepare X.Y.Z --dry-run
./scripts/release.py prepare X.Y.Z
# Merge the release PR and wait for master push CI.
./scripts/release.py check X.Y.Z
./scripts/release.py publish X.Y.Z
```

Replace `X.Y.Z` with the chosen stable version. Tags use `vX.Y.Z`.
Publication requires both `build-test-docs` and `Release tooling checks` for
the exact source SHA, consistent Japanese/English README and CHANGELOG versions, and Immutable
releases enabled on GitHub.

See [the release guide](docs/releasing.md) for authentication, repository
protection, command behavior, and recovery. `scripts/release.sh` forwards the
same subcommands to Python.
