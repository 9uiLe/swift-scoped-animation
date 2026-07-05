# How It Works

ScopedAnimation uses SwiftUI transactions as the runtime boundary mechanism.

## Transaction Model

SwiftUI carries animation information through a `Transaction`. ScopedAnimation adds an internal transaction stamp with two pieces of data:

- the `AnimationScope` identifier, and
- the actual `Animation` used for that transaction.

Every scope boundary uses a strip-then-restore rule:

1. Strip `transaction.animation` from every incoming transaction.
2. Read the internal stamp.
3. Restore the stamped animation only when the stamp belongs to that exact scope.
4. Do not restore when `transaction.disablesAnimations == true`.

This means ancestor animations do not flow into the scope. Proxy-driven animations are restored only inside the scope that created them. Nested scopes work because an outer stamped transaction is stripped at the inner boundary and is not restored there.

## Nested Scope Semantics

Nested `AnimationScope` values do not compose multiple animations over the same
subtree. The descendant boundary wins because it strips every incoming animation
and restores only a stamp with its own scope identifier.

That includes value-driven scopes. If an outer value-driven scope stamps a
transaction, an inner scope boundary treats that stamp as belonging to another
scope and leaves `transaction.animation` as `nil`. The stamp is still present,
but the animation effect is intentionally blocked at the descendant boundary.

In DEBUG builds, ScopedAnimation reports this as `crossScopeAnimationStrip` when
the stripped transaction carried another scope's stamped animation. The warning
is not a leak warning; it is a composition warning. Use sibling scopes for
separate visual layers, `AnimationScope(name:triggers:)` when one subtree needs
multiple triggers, or move the animation owner closer to the affected subtree.

## Multi-Trigger Scopes

When several `(animation, value)` pairs affect the same subtree, declare them in
one scope instead of nesting:

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

If multiple trigger values change in the same transaction, the trigger closest to
the start of the array wins. DEBUG builds report `multiTriggerConflict` when a
lower-priority trigger was ignored.

## Value-Driven Scopes

The value-driven initializer applies SwiftUI's `.animation(_:value:)` behavior inside the boundary and stamps the resulting transaction. The stamp is downstream-only: views above the scope do not see it.

If a scoped `.animation(_:value:)` transaction arrives with no stamp, or with a stamp that carries a different animation, the scope stamps it again so the animation is attributed to the scope that actually created the value-driven animation.

## Proxy-Driven Scopes

`AnimationScopeProxy.animate(_:)` runs its body with a stamped transaction. The stamp travels widely, but only the matching scope boundary restores its animation. That keeps the animation effect inside the scope's subtree.

```swift
AnimationScope(.snappy, name: "Menu") { scope in
  Button("Toggle") {
    scope.animate {
      isOpen.toggle()
    }
  }
}
```

## Barriers

`animationBarrier()` strips only `transaction.animation`. It preserves the internal stamp so a nested `AnimationScope` below the barrier can still restore its own animation.

In DEBUG builds, barriers report only transactions that have animation but no stamp. Stamped transactions are treated as normal scoped traffic.

## Blocking + Detection, Not Total Containment

SwiftUI state updates are not structurally contained. A raw `withAnimation` can still update every view that reads the changed state. ScopedAnimation therefore does not claim total containment.

The library provides:

- blocking of incoming animation at scope and barrier boundaries,
- source tracking for scoped transactions, and
- DEBUG detection of unstamped animation transactions.

Use these tools to make animation ownership visible and to catch unscoped animation early. Do not rely on the library to prove that every possible animation leak has been detected.

## Detection Accuracy

The leak detector observes transactions that pass through the view where it is installed.

| Leak source | Root detector | Subtree detector / barrier sensor |
| --- | --- | --- |
| Raw `withAnimation` or unstamped `withTransaction` | Detected with high confidence | Detected |
| Raw `.animation(_:value:)` outside a scope | Not detected when the transaction is created below the detector | Detected if the detector is downstream of the source |
| Scoped transaction with a stamp | Not reported | Not reported |

The raw `.animation(_:value:)` blind spot is handled with three layers:

1. barrier sensors around intentionally static or legacy subtrees,
2. `detectAnimationLeaks()` on suspicious subtrees while debugging, and
3. a future static rule for teams that want to ban raw `.animation(` calls.

## List Support

Phase 1 QA verified `List` behavior on iPhone 17 Simulator running iOS 26.5:

- `AnimationScope` wrapping a `List` propagated scoped animation into visible row content.
- `animationBarrier()` in rows stripped incoming raw animation.
- Row behavior remained correct after scrolling rows offscreen and back.

This relies on SwiftUI transaction propagation through `List`, which is not a documented contract from Apple. Treat it as an observed behavior that is covered by the sample app QA and CI build checks, not as an OS-level guarantee. Re-run the List QA when adopting a new major Xcode or OS release.
