# ScopedAnimation microbenchmarks

Run from the repository root on macOS with the supported Xcode toolchain:

```sh
bash scripts/benchmark-performance.sh release
bash scripts/benchmark-performance.sh debug
```

The script compiles the library sources and benchmark in the same module so it
can measure internal history resolution and diagnostics without adding a package
product or dependency. RELEASE uses `-O`; DEBUG uses `-Onone -D DEBUG`. Both target
macOS 14 or later and Swift 6. The temporary executable is removed after the run.

Each case warms up with 100 operations, then reports the minimum, median, and
maximum of seven batches in nanoseconds per operation. The checksum consumes
results to prevent dead-code elimination. Timing thresholds are not CI tests.
Avoid concurrent builds, simulators, and other CPU-intensive work while measuring.

Reference timings and interpretation are recorded in
[the performance model](../docs/performance.md).

## Cases

- **History:** prebuilt snapshots alternate with no changed values, a changed
  first trigger, or a changed last trigger. Counts 1, 2, and 8 represent small
  configurations; 64 is a scaling stress case. Snapshot construction is excluded.
- **Collection values:** eight independently allocated 1,024-element integer
  arrays, with a change at the end of the last array. This isolates expensive
  value equality and is not a typical two-scalar-trigger scope.
- **Construction and comparison:** two new eight-trigger snapshots are built and
  compared each iteration. This includes allocation, type erasure, and equality.
- **Suppressed DEBUG conflicts:** eight changed triggers, with one or 64 warning
  sites. Warmup reports each site once. A fixed injected time keeps later reports
  inside the debounce window. The sink reads accepted messages and checks the
  exact number of emitted warnings; console I/O is excluded from the timings.

To compare against a saved source tree with the same internal interfaces:

```sh
SCOPED_ANIMATION_BENCHMARK_SOURCES=/path/to/ScopedAnimation \
  bash scripts/benchmark-performance.sh release
```

That directory must contain the library Swift sources and its `Diagnostics/`
subdirectory. Benchmark the two versions sequentially on the same machine using
identical flags and fixtures. Record raw CSV output and toolchain details.

These measurements exclude SwiftUI body evaluation, transaction propagation,
layout, rendering, and frame scheduling. Use the Performance Playbook and
Instruments on a representative app/device to evaluate those costs. A faster
history resolver does not imply the same percentage improvement in frame time.
