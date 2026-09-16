# Contributing

[日本語](CONTRIBUTING.md) | English

Development connects product contracts, implementation, and verification evidence.
Start with [README](README.en.md) for usage and [HANDOFF.md](HANDOFF.md) for product
scope, public API, semantics, and roadmap.

## Development workflow

1. Read the relevant design contract, implementation, and tests.
2. For public API, semantic, or roadmap-order changes, update the design and explain the reason in the PR.
3. Update implementation, contract tests, DocC, and relevant documents together.
4. Record user-facing changes under `## Unreleased` in `CHANGELOG.md`.
5. Run validation and include the environment, actual output, and unverified areas in the PR.

The product provides **animation blocking and detection**. State changes update
views outside scopes, and proxy transactions reach regions without boundaries.
Documentation and tests must reflect that scope of behavior.

## Language policy

Japanese is the primary language. Issues, PRs, and reports in English are welcome.

| Content | Language and maintenance |
| --- | --- |
| Design, operating guides, DocC, API and implementation comments | Japanese |
| Diagnostics, errors, CLI guidance, sample UI, test display names | Japanese |
| Issues, PRs, commit messages | Japanese by default; commits also explain motivation |
| README, contribution guide, security policy, code of conduct | Japanese and `.en.md` English editions |
| API, type, variable and file names, CLI subcommands, machine-facing identifiers | English |
| Execution logs, measurements, external quotations, MIT license | Original text |

English editions describe the same contracts needed to use and contribute to the
library. Provide reciprocal links and update corresponding content in the same
PR. Detailed design and operating guides, including DocC, are maintained in Japanese.

Tools depend on these fixed spellings:

- Required CI jobs: `build-test-docs`, `Release tooling checks`
- CHANGELOG headings: `## Unreleased`, `## X.Y.Z - YYYY-MM-DD`
- DocC syntax: `Overview`, `Topics`, `Parameter`, and related directives

Both READMEs must declare the same installation version. Release commands update
both and check for missing files, duplicate declarations, and version mismatches.

## Information ownership

| Information | Location |
| --- | --- |
| Product scope, API contracts, internal responsibilities, roadmap | `HANDOFF.md` |
| Installation and API usage | README, DocC, public API doc comments |
| Implementation mechanics | Code names, types, and control flow |
| Required behavior | Test names, setup, and assertions |
| Motivation for a change | Commit history |
| Non-obvious constraints that rule out a simpler implementation | Implementation comments |
| User-facing changes and migration steps | `CHANGELOG.md` |
| Environment, source identity, actual output, observation limits | `docs/validation.md`, performance and QA records |

Design and usage guides define their own terms and prerequisites. Readers should
not need a conversation, an earlier PR, or the order of implementation work.
Validation records state their dates and scope so each result is tied to what that
run actually verified.

## Repository map

| Path | Responsibility |
| --- | --- |
| `Sources/ScopedAnimation/` | Scope composition, value resolution, boundaries, proxies, stamps |
| `Sources/ScopedAnimation/Diagnostics/` | DEBUG warnings, leak detection, overlay |
| `Sources/ScopedAnimation/Documentation.docc/` | Public API guides |
| `Tests/ScopedAnimationTests/` | Behavioral and pure tests grouped by contract |
| `Tests/ScopedAnimationTests/Support/` | Hosting, transaction recording, fixtures |
| `Examples/ScopedAnimationExample/` | Interactive iOS sample |
| `Examples/QA.md` | Manual QA procedures and observations |
| `Benchmarks/` | Internal CPU measurement code and method |
| `scripts/`, `scripts/tests/` | Release, benchmark and diagnostic-audit commands; release-tooling tests |
| `docs/` | Compatibility assumptions, reference measurements, validation records, release guide |

## Development requirements

- Xcode 26.x / Swift 6.3
- SwiftPM, no external dependencies
- Swift 6 language mode, complete strict concurrency checking
- Python 3.10+ for release-tooling tests (standard library only)

## Local checks

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


CI validates the package and release tooling with read-only permissions. Include
actual output when reporting success and identify checks that were not run.
Follow [Examples/QA.md](Examples/QA.md) for manual QA.

## API documentation and diagnostics

Document every public API's contract and usage with DocC; include a short example
for every public type. Guard diagnostic implementations with `#if DEBUG`.
Update markers in `scripts/verify-release-diagnostics.sh` when adding or renaming
diagnostics. The audit verifies their presence in DEBUG before checking their
absence from RELEASE binaries using `strings` / `nm`.

## Test design

Use Swift Testing and group tests by contract. Hosting and warning-capture tests
belong under the serialized `AnimationScopeBehaviorTests` suite so run-loop updates
and replacement of the global warning sink cannot overlap. Retain each host and
close it with `defer`. Use the run loop or explicit expectations to wait.

An empty transaction-spy recording must fail even a negative animation assertion.
Compare `Animation` values directly. Check the stamp on the same recorded
transaction when asserting ownership. Keep pure value-comparison, trigger-selection,
and bounded-debounce tests independent of hosting.

Release-tooling tests use temporary Git repositories and simulated GitHub
responses. They must not publish real tags or releases.

## Performance measurements

Run `bash scripts/benchmark-performance.sh release` and
`bash scripts/benchmark-performance.sh debug` sequentially, without concurrent
builds or simulator work. Follow [the benchmark procedure](Benchmarks/README.md)
and record the environment, compiler settings, operation definitions, and raw
values. Internal CPU timings do not establish frame-rate or allocation-count
improvements. Profile applications on their target devices.

## Releasing

The owner merges a release-document PR and verifies master push CI for its source
SHA before publishing. The [release guide](docs/releasing.md) defines authentication,
repository protection, rejection conditions, and recovery.

```sh
./scripts/release.py prepare X.Y.Z --dry-run
./scripts/release.py prepare X.Y.Z
# Merge the release PR and wait for master push CI.
./scripts/release.py check X.Y.Z
./scripts/release.py publish X.Y.Z
```

`X.Y.Z` is the chosen numeric stable version. Publication requires both mandatory
jobs to succeed, matching CHANGELOG and README versions in both languages, and
GitHub Immutable releases enabled. Artifacts are an annotated `vX.Y.Z` tag and a
source-only GitHub Release. `scripts/release.sh` forwards the same subcommands to Python.
