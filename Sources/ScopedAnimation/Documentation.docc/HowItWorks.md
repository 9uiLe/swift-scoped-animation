# How It Works

Follow a transaction from its animation source through scope boundaries.

## Transactions and Stamps

SwiftUI carries animation information in a `Transaction`. ScopedAnimation adds
an internal stamp containing a stable scope ID, an optional display name, and the
animation selected for that transaction.

The ID determines ownership. A name helps diagnostics identify the scope, and an
animation payload lets a matching boundary restore the intended animation.
Changing the name or payload does not replace the scope's identity.

## Boundary Processing

Every scope boundary:

1. removes `transaction.animation`;
2. preserves the stamp for descendants; and
3. restores the stamp's animation only when its ID matches this scope and
   `transaction.disablesAnimations` is false.

A standalone `animationBarrier()` performs the first two steps and never restores
animation. Both use the same boundary implementation.

```text
Incoming transaction
    ↓
Boundary: strip, preserve stamp, restore matching animation when enabled
    ↓
Value resolver: supply local animation and stamp when a trigger changes
    ↓
Content and any descendant boundaries
```

The boundary is outside the value resolver in the modifier chain, so incoming
animation is processed before a local value change supplies its animation.

## Value-Driven Animation

A value-driven scope pairs each observed value with an animation:

```swift
AnimationScope(
    name: "Board",
    triggers: [
        .animation(.easeOut(duration: 0.12), value: selectedPoints),
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints),
    ]
) {
    BoardView()
}
```

The resolver compares snapshots by array position and selects the first changed
trigger. That one resolution supplies the transaction animation, scope stamp,
and DEBUG conflict report.

The same modifier structure handles zero, one, or many triggers.
`.transaction(value:)` gates delivery by snapshot value. History retains a
pending resolution across repeated body evaluations so an early evaluation does
not consume the animation before SwiftUI delivers its transaction.

| Change | Behavior |
| --- | --- |
| Initial mount | Establish a baseline. |
| One or more values change | Select the first changed trigger and stamp the local update. |
| Several values change | Report ignored changed triggers in DEBUG. |
| Animation or name changes alone | No value-driven animation. The next value change uses current configuration. |
| Trigger count changes | Establish a baseline without a trigger animation or conflict warning; preserve content identity. |
| Trigger order changes | Compare values by their new positions and use those positions for priority. |
| Value type changes | Treat the values as different, including `Int` versus `Optional<Int>`. |
| Animations are disabled | Do not apply a value-driven resolution. |

The single-value initializer supplies one trigger to this resolver. An empty
trigger array provides a named boundary and DEBUG outline without value-driven
animation or the barrier's unstamped-animation warning.

Value-driven stamps travel downstream from the resolver. Observers above the
scope do not see the local animation or stamp.

## Proxy-Driven Animation

```swift
AnimationScope(.snappy, name: "Menu") { scope in
    Button("Toggle") {
        scope.animate {
            isOpen.toggle()
        }
    }
}
```

The proxy creates a transaction with its animation and stamp, then runs the
closure with `withTransaction`. The stamp can reach root and descendant
observers. A matching scope restores the animation after ancestor boundaries
strip it.

Views outside declared boundaries can receive the original animation. Every view
that reads changed state can still update. Use scopes or barriers around
unrelated regions that must reject incoming animation.

## Nested Ownership

A descendant scope is an independent boundary:

- An outer proxy animates the outer region; an inner scope strips its animation.
- An inner proxy's stamp crosses outer boundaries and is restored at the matching
  inner scope.
- An outer value-driven animation is stripped at an inner scope.
- If an inner trigger also changes, it supplies its own animation and stamp,
  even when its animation equals the outer animation.

DEBUG `crossScopeAnimationStrip` warnings identify a boundary that removed
another scope's stamped animation. This is a composition diagnostic.
`multiTriggerConflict` identifies competing changed values within one scope.
See <doc:Composition> for choosing a scope structure.

## Diagnostic Visibility

A detector reports non-nil animation without a stamp only when that transaction
passes through its installation point.

| Source | Root detector | Downstream detector or barrier sensor |
| --- | --- | --- |
| Unstamped `withAnimation` or animated `withTransaction` | Detects passing transactions | Detects passing transactions |
| Raw value animation created below the root detector | Cannot observe it | Detects it when downstream of its source |
| Stamped animation | No leak report | No leak report |

Use screen-level detectors, barriers around static or legacy regions, and local
detectors on suspicious subtrees. Review raw view animation modifiers because
they can generate transactions below observation points. A stamp establishes
scope attribution, not proof that every animated view belongs to the intended
subtree.

Warnings are debounced by kind and applicable scope name, with bounded storage.
Suppressed warnings skip message formatting. Diagnostics and boundary overlays
compile out of RELEASE builds.

## Framework Compatibility

Boundary behavior depends on SwiftUI transaction propagation. Hosted behavioral
tests verify supplied transactions on macOS and iOS. They do not verify
intermediate animation frames.

The unit-hosting harness does not reliably observe `List` row transaction hooks.
Use the example app's List QA screen to verify propagation, row barriers, and
reuse on the target environment. An example build alone does not establish
those behaviors.
