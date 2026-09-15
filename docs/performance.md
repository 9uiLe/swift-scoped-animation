# Performance model and reference measurements

ScopedAnimation's CPU work consists of trigger construction, value comparison,
transaction boundary processing, and DEBUG diagnostics. This document records
the cost model and a reference run of the internal microbenchmarks.

For application-level profiling, use the
[Performance Playbook](../Sources/ScopedAnimation/Documentation.docc/PerformancePlaybook.md).
For exact fixtures and execution instructions, see
[Benchmarks/README.md](../Benchmarks/README.md).

## Cost model

| Operation | Work performed |
| --- | --- |
| Trigger construction | Store the animation, erase the value type, and allocate array/closure storage as needed. |
| Snapshot comparison | Compare concrete value types and values by position. Animation configuration does not participate in equality. |
| History resolution | Classify unchanged, resized, or changed snapshots in one pass and retain a pending resolution. |
| RELEASE selection | Stop at the first changed trigger. |
| DEBUG selection | Collect the first changed trigger and any lower-priority changed triggers. |
| Boundary | Remove incoming animation, preserve its stamp, and restore animation only for a matching enabled scope. |
| Suppressed warning | Build a site key, acquire the warning-state lock, and consult bounded debounce storage. |
| Accepted warning | Deliver a typed event; format its message when the sink reads it. |
| DEBUG overlay | Collect anchors and resolve bounds for displayed scope outlines. |

SwiftUI's transaction value gate compares snapshots separately from history.
A proxy scope has an empty trigger snapshot; a standalone barrier has no trigger
history. Diagnostics and rejected-trigger storage are absent from RELEASE builds.

Equality complexity belongs to the supplied value type. Large arrays or sets can
dominate bookkeeping. Use a scalar or small domain value when it fully represents
the animation condition. A revision counter is suitable only if every relevant
mutation advances it reliably.

## Reference environment

- Date: 2026-09-16
- Hardware: Apple M1 Pro
- OS: macOS 26.2 (25C56)
- Xcode: 26.5 (17F42)
- Swift: Apple Swift 6.3.2, Swift 6 language mode
- Target: macOS 14
- RELEASE flags: `-O`
- DEBUG flags: `-Onone -D DEBUG`

The script compiles library and benchmark sources in the same module to access
internal interfaces. No benchmark product or dependency is added to the package.
The temporary executable is removed after execution.

Each case warms up with 100 operations, then measures seven batches.
Scalar and construction batches contain 20,000 operations; collection and
diagnostic batches contain 2,000. Results consume a checksum to prevent
dead-code elimination. The diagnostic fixture verifies exactly one accepted
warning per warmed site; timed repeats stay inside the debounce window.

## Measured CPU time

Values are **microseconds per operation**, using each case's median across seven
batches. `changed=-1` denotes unchanged values; other numbers identify the
changed array position. Fixtures are defined in the benchmark guide.

| Build | Case | Median (µs) |
| --- | --- | ---: |
| RELEASE | `history/count=1/changed=-1` | 0.089 |
| RELEASE | `history/count=1/changed=0` | 0.257 |
| RELEASE | `history/count=2/changed=-1` | 0.170 |
| RELEASE | `history/count=2/changed=0` | 0.226 |
| RELEASE | `history/count=2/changed=1` | 0.308 |
| RELEASE | `history/count=8/changed=-1` | 0.585 |
| RELEASE | `history/count=8/changed=0` | 0.225 |
| RELEASE | `history/count=8/changed=7` | 0.711 |
| RELEASE | `history/count=64/changed=-1` | 4.560 |
| RELEASE | `history/count=64/changed=0` | 0.224 |
| RELEASE | `history/count=64/changed=63` | 4.712 |
| RELEASE | `history/8x1024-element-arrays/changed=7` | 86.735 |
| RELEASE | `construct-and-compare/two-8-trigger-snapshots` | 4.329 |
| DEBUG | `history/count=1/changed=-1` | 0.839 |
| DEBUG | `history/count=1/changed=0` | 1.090 |
| DEBUG | `history/count=2/changed=-1` | 1.150 |
| DEBUG | `history/count=2/changed=0` | 1.406 |
| DEBUG | `history/count=2/changed=1` | 1.401 |
| DEBUG | `history/count=8/changed=-1` | 2.993 |
| DEBUG | `history/count=8/changed=0` | 3.274 |
| DEBUG | `history/count=8/changed=7` | 3.244 |
| DEBUG | `history/count=64/changed=-1` | 20.182 |
| DEBUG | `history/count=64/changed=0` | 20.554 |
| DEBUG | `history/count=64/changed=63` | 20.500 |
| DEBUG | `history/8x1024-element-arrays/changed=7` | 89.266 |
| DEBUG | `construct-and-compare/two-8-trigger-snapshots` | 8.991 |
| DEBUG | `suppressed-conflict/sites=1` | 0.860 |
| DEBUG | `suppressed-conflict/sites=64` | 1.633 |

A two-scalar-trigger history with its second value changing takes about 0.31 µs
in this RELEASE run. The eight-array fixture takes about 87 µs. These cases
illustrate the effect of value equality complexity; they do not represent a full
SwiftUI update.

Raw measurements include minimum, median, maximum, iterations, and checksum:

- [RELEASE CSV](benchmarks/2026-09-16-release.csv)
- [DEBUG CSV](benchmarks/2026-09-16-debug.csv)

## Reproduce a run

From the repository root:

```sh
bash scripts/benchmark-performance.sh release
bash scripts/benchmark-performance.sh debug
```

Run configurations sequentially without concurrent builds, simulators, or other
CPU-intensive work. Record the environment and raw output for each run.
Scheduling, hardware, and compiler changes can affect small differences.
Microbenchmark timing thresholds are not CI pass/fail tests.

## Measurement boundaries

These fixtures do not measure:

- SwiftUI body evaluation or the transaction gate's own snapshot comparisons;
- transaction propagation, layout, rendering, or frame scheduling;
- memory-allocation counts or peak memory;
- overlay layout and rendering;
- application frame rate or physical-device energy use.

The construction case includes the time spent on allocation and type erasure but
does not count allocations. The diagnostic case uses a sink instead of console
I/O. Neither case establishes end-to-end application cost.

A scope does not sever state dependencies or prevent body invalidation. Keep
animated subtrees small, avoid expensive derived trigger values, and profile the
representative interaction on its target device.

## Performance invariants and validation

The semantic suite checks that repeated snapshot evaluations retain a pending
selection, trigger resizing clears and rebases it, and unrelated updates remain
unanimated. A diagnostic test uses a custom animation with an observable
description to verify that accepted warnings format their messages and suppressed
warnings do not.

[Validation results](validation.md) include macOS and iOS behavior checks,
RELEASE tests, and an audit for diagnostic symbols and strings.
