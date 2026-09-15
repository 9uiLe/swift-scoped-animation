# Animation Performance Playbook

Choose a small animated subtree and measure its cost on the target device.

## Animation Scope and State Updates

A scope changes the animation carried by transactions. It does not sever state
dependencies or guarantee fewer `body` evaluations. Views outside a scope still
update when their inputs change.

Place a scope around the content that owns the motion:

```swift
VStack {
    Header()

    AnimationScope(.smooth, value: isExpanded, name: "Card body") {
        CardBody(isExpanded: isExpanded)
    }

    Footer()
}
```

Use barriers where incoming animation must be removed. Layout remains a separate
responsibility: a barrier cannot keep a region stationary when ancestor layout
moves it.

## Trigger Costs

A value-driven scope constructs triggers, compares their values, and applies a
selected animation when the transaction's value gate permits it.

- History compares values in declaration order. RELEASE stops at the first
  changed trigger; DEBUG inspects remaining triggers to identify conflicts.
- An unchanged snapshot requires all values to compare equal.
- SwiftUI's `.transaction(value:)` gate compares snapshots separately.
- Equality depends on the supplied type. Large arrays and sets can dominate
  bookkeeping.
- Trigger creation includes type erasure and array/closure storage.

Prefer a scalar or small domain value when it fully represents the intended
animation condition. A revision counter is useful only if every relevant
mutation reliably advances it. Avoid constructing large derived collections
solely to trigger an animation.

A proxy scope uses an empty trigger snapshot. A standalone barrier requires no
trigger history and is appropriate when only stripping is needed.

## DEBUG Costs

Leak detectors execute transaction hooks. Place them at screen boundaries or on
suspicious subtrees; installing one on every row multiplies observation work.

Warnings are debounced with bounded storage. Suppressed warnings skip message
formatting but still perform site lookup and locking. The overlay collects
anchor preferences and resolves scope bounds during layout. Use it while
inspecting ownership.

Diagnostic implementations, overlay registration, and rejected-trigger storage
compile out of RELEASE builds. Measure application performance in the
configuration used for shipping.

## Visual Properties

These properties usually avoid broad layout work:

- `opacity`
- `scaleEffect`
- `offset`
- `rotationEffect`

Measure layout-sensitive properties such as `frame`, `padding`, and `font`,
and expensive effects such as large `blur` or `shadow`. Their cost depends on
the content, repetition, and interaction frequency.

## Profile the Application

Choose the Instruments template for the execution target:

| Target | Template and interpretation |
| --- | --- |
| Physical iPhone or iPad, or a macOS app on the host Mac | Use the SwiftUI template to inspect update causes and expensive view work. |
| iOS Simulator | Use Time Profiler for CPU, hang, and hitch investigation. The SwiftUI lane is not populated, and host rendering does not establish physical-device rendering performance. |

1. Reproduce a representative interaction on the target.
2. Record body updates, layout work, CPU time, and rendering symptoms.
3. Identify the state dependencies and subtrees involved.
4. Change one cause and repeat the same interaction.
5. Keep the result only when it preserves behavior and improves the relevant
   measurement.

An animation boundary alone establishes no frame-rate or rendering-cost claim.

## Measure Library Bookkeeping

The repository's `scripts/benchmark-performance.sh` measures history resolution,
snapshot construction and comparison, expensive equality, and suppressed DEBUG
warnings. `Benchmarks/README.md` defines the fixtures, compiler flags, and method.

Those timings measure internal CPU operations. They exclude SwiftUI updates,
transaction propagation, layout, rendering, allocation counts, and frame
scheduling. Use them to assess library bookkeeping alongside application traces.
