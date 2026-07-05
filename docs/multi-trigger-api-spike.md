# Multi-Trigger AnimationScope API Spike

Date: 2026-07-04
Status: Design spike only. No implementation or public API change is included.

## Summary

Recommendation: Go for an additive cumulative trigger API, gated by a small
implementation spike that verifies SwiftUI modifier ordering and simultaneous
trigger precedence. No-Go on changing nested `AnimationScope` propagation.

The proposed direction is a single scope with one stamp and one boundary, plus
multiple value-driven trigger pairs:

```swift
AnimationScope(name: "Board") {
  BoardView(
    selectedPoints: selectedPoints,
    hintPoints: hintPoints
  )
}
.scopeAnimation(.easeOut(duration: 0.12), value: selectedPoints)
.scopeAnimation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints)
```

This is meant to cover "one subtree, multiple `(animation, value)` pairs"
without nesting scopes. Nested scopes should keep the current semantics:
descendant boundaries strip ancestor scoped animations and restore only their own
stamp.

## Problem

The current API has one value-driven trigger per `AnimationScope`:

```swift
AnimationScope(.easeOut(duration: 0.12), value: selectedPoints, name: "Selection") {
  BoardView(selectedPoints: selectedPoints)
}
```

When users need two independent triggers on the same subtree, nesting looks
natural but is semantically wrong:

```swift
AnimationScope(.easeOut(duration: 0.12), value: selectedPoints, name: "Selection") {
  AnimationScope(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints, name: "Hint") {
    BoardView(selectedPoints: selectedPoints, hintPoints: hintPoints)
  }
}
```

The inner boundary strips the outer scope's stamped transaction because the
stamp IDs differ. That is correct for the existing strip-then-restore model, but
it means nesting cannot represent multiple triggers for one subtree.

M1 added a DEBUG warning for this case:
`crossScopeAnimationStrip`. The warning makes the misuse visible; it does not
provide a replacement API.

## Design Goals

- Preserve the existing boundary semantics: one boundary restores only its own
  stamp.
- Avoid changing nested scope behavior.
- Keep the API additive and source-compatible with existing single-trigger and
  proxy-driven scopes.
- Keep zero external dependencies.
- Make simultaneous trigger behavior deterministic and documented.
- Make the intended shape more discoverable than falling back to raw
  `.animation(_:value:)` exceptions.

## Proposed API Shape

Primary proposal: make `.scopeAnimation(_:value:)` a cumulative method on
`AnimationScope`, not a general `View` extension.

API sketch:

```swift
public struct AnimationScope<Content: View>: View {
  public init(name: String? = nil, @ViewBuilder content: @escaping () -> Content)

  public func scopeAnimation<Value: Equatable>(
    _ animation: Animation,
    value: Value
  ) -> AnimationScope<Content>
}
```

The existing single-trigger initializer can remain as source-compatible sugar:

```swift
AnimationScope(.smooth, value: isSelected, name: "Selection") {
  SelectionIndicator(isSelected: isSelected)
}
```

is equivalent in meaning to:

```swift
AnimationScope(name: "Selection") {
  SelectionIndicator(isSelected: isSelected)
}
.scopeAnimation(.smooth, value: isSelected)
```

Proxy-driven scopes can stay compatible:

```swift
AnimationScope(.snappy, name: "Board") { scope in
  BoardView()
    .onTapGesture {
      scope.animate {
        isExpanded.toggle()
      }
    }
}
.scopeAnimation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints)
```

This says: proxy-triggered updates and value-triggered updates share the same
scope stamp and boundary, but a single SwiftUI transaction can still carry only
one `Animation`.

## Internal Model

The current model stores one scope animation plus one optional trigger value.
The multi-trigger model would store:

- one stable `AnimationScopeStamp` per `AnimationScope`;
- optional default proxy animation for `scope.animate {}`;
- an ordered list of value triggers, each containing an `Animation` and an
  erased `Equatable` value.

Sketch:

```swift
private struct ScopeAnimationTrigger {
  let animation: Animation
  let value: AnyEquatable
}
```

The scope body should keep the current high-level order:

1. Render content with one named stamp.
2. Stamp any non-nil local animation transaction with that scope stamp.
3. Apply every value-driven trigger inside the same scope.
4. Apply exactly one `AnimationScopeBoundaryModifier` with the same stamp.

Conceptually:

```swift
let stampedContent = content(proxy)
  .transaction { transaction in
    if let animation = transaction.animation {
      transaction.animationScopeStamp = stamp.withAnimation(animation)
    }
  }

let triggeredContent = triggers.applyValueAnimations(to: stampedContent)

triggeredContent
  .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
```

The important point is that `AnimationScopeStamp.animation` remains the animation
selected for the current transaction. It does not need to store all configured
trigger animations. The boundary still restores one animation from one matching
stamp.

## Semantics

When one trigger value changes, the scope behaves like today's value-driven
scope: the resulting transaction gets that trigger's animation, receives the
scope stamp, crosses the boundary, and is restored because the stamp ID matches.

When two trigger values change in the same update pass, SwiftUI still exposes
only one `Transaction.animation`. The API must define a deterministic rule. The
recommended rule is:

> Later `.scopeAnimation(_:value:)` calls have higher precedence when multiple
> configured values change in the same transaction.

That matches the mental model of cumulative modifiers, but it must be verified
with the transaction-spy harness before committing to the API.

Nested scopes remain unchanged. A descendant scope still strips an ancestor
scope's stamped animation and restores only its own matching stamp. The
multi-trigger API avoids the nesting problem by keeping all relevant triggers in
one scope.

Sibling scopes remain the right shape for separate subtrees:

```swift
HStack {
  AnimationScope(.easeOut(duration: 0.12), value: selectedPoints, name: "Selection") {
    SelectionLayer(selectedPoints: selectedPoints)
  }

  AnimationScope(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints, name: "Hint") {
    HintLayer(hintPoints: hintPoints)
  }
}
```

## Relationship to `crossScopeAnimationStrip`

`crossScopeAnimationStrip` should remain exactly about cross-scope strip events.

With the proposed API, multiple configured triggers share one
`AnimationScopeStamp.id`, so the scope boundary sees its own stamp and restores
the selected animation. There is no cross-scope strip and no
`crossScopeAnimationStrip` warning.

If users still nest scopes to represent one subtree with multiple triggers, the
current warning remains correct:

```swift
AnimationScope(.easeOut(duration: 0.12), value: selectedPoints, name: "Selection") {
  AnimationScope(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints, name: "Hint") {
    BoardView(selectedPoints: selectedPoints, hintPoints: hintPoints)
  }
}
```

When `selectedPoints` changes, the inner `"Hint"` boundary strips the stamped
animation from `"Selection"` and should report `crossScopeAnimationStrip` in
DEBUG.

If a multi-trigger scope contains a nested child scope, the same rule applies:
ancestor transactions are blocked by the child scope boundary. The new API does
not turn nested scopes into composable trigger layers.

`animationBarrier()` is not changed. It strips incoming animation and keeps the
stamp for downstream scopes, but it does not restore animations and should not
become the multi-trigger composition primitive.

Once the new API exists, the warning message and docs can add a more actionable
hint: use sibling scopes for separate subtrees, or `.scopeAnimation(_:value:)`
for multiple triggers on one subtree.

## Implementation Cost

Estimated cost: medium.

Expected implementation work:

- Refactor `AnimationScope` internals from `animation + triggerValue` to
  `proxyAnimation + [ScopeAnimationTrigger]`.
- Add a no-default-animation initializer for value-only cumulative scopes.
- Add the cumulative `.scopeAnimation(_:value:)` method on `AnimationScope`.
- Preserve existing initializers as sugar over the new internal model.
- Add an internal helper that applies an ordered runtime list of value-driven
  `.animation(_:value:)` modifiers.
- Keep one `AnimationScopeBoundaryModifier` per scope.
- Update DocC, README, and changelog after the API is accepted.

Expected tests:

- Existing single-trigger value scope behavior remains unchanged.
- Each trigger in a two-trigger scope animates the same child subtree when
  changed independently.
- Both triggers share one stamp and do not emit `crossScopeAnimationStrip`.
- A nested child scope still strips ancestor scoped animations and emits
  `crossScopeAnimationStrip`.
- Simultaneous trigger changes follow the documented precedence rule.
- Proxy-driven updates still restore through the same boundary.
- `transaction.disablesAnimations == true` still prevents restoration.

Main risks:

- SwiftUI modifier ordering must be verified for multiple `.animation(_:value:)`
  modifiers on the generated view chain.
- Dynamic trigger lists may require type erasure or a small recursive helper.
  That is acceptable for the expected small trigger count, but should be kept
  internal.
- A zero-trigger `AnimationScope(name:)` is effectively a named boundary. That
  may be useful, but it needs explicit documentation.
- Proxy and value triggers that fire in the same update cannot both win because
  the transaction has one animation slot.

## Alternatives

### Alternative A: Keep documentation-only guidance

Do nothing beyond the M1 warning and M2 docs. Users use sibling scopes when the
UI can be split, and raw `.animation(_:value:)` exceptions when the same subtree
needs multiple triggers.

Pros:

- No API or implementation risk.
- Preserves the current small surface area.

Cons:

- Leaves a real same-subtree use case outside the library.
- Encourages exceptions to the "no raw animation" migration path.
- Makes `crossScopeAnimationStrip` a warning without a first-party fix.

### Alternative B: Let nested scopes compose ancestor animations

Change `AnimationScopeBoundaryModifier` so descendant boundaries preserve or
restore ancestor scope animations.

Pros:

- Makes the tempting nested syntax work.

Cons:

- Violates the core rule that a boundary restores only its own stamp.
- Weakens the "inner scope wins" model documented in `HANDOFF.md`.
- Risks letting ancestor animations affect content that a child scope intended
  to isolate.
- Would make M1's `crossScopeAnimationStrip` warning less meaningful.

Recommendation: No-Go.

### Alternative C: General `View.scopeAnimation(_:value:)`

Make `.scopeAnimation(_:value:)` a `View` extension that feeds the nearest
descendant `AnimationScope`, likely through environment accumulation.

Pros:

- More flexible placement.
- Works after common view modifiers if designed carefully.

Cons:

- Can silently do nothing when no descendant scope consumes it.
- Requires nearest-scope consumption rules so nested scopes do not accidentally
  inherit ancestor trigger configuration.
- More complex to explain and test.

Recommendation: keep this as a fallback only if the `AnimationScope` method is
too restrictive in real examples.

### Alternative D: Builder-style trigger list

Use an initializer or builder for trigger declarations:

```swift
AnimationScope(name: "Board", triggers: [
  .value(.easeOut(duration: 0.12), selectedPoints),
  .value(.spring(response: 0.35, dampingFraction: 0.7), hintPoints),
]) {
  BoardView()
}
```

Pros:

- Keeps all trigger declarations inside the scope initializer.

Cons:

- Heterogeneous `Equatable` values still require type erasure.
- Less idiomatic than SwiftUI's modifier accumulation.
- Harder to read when trigger expressions are long.

Recommendation: No-Go as the primary API.

## Go / No-Go Recommendation

Go for a cumulative `.scopeAnimation(_:value:)` API on `AnimationScope`, with
these gates:

1. Prove modifier ordering and simultaneous trigger precedence with spy-based
   tests before documenting the precedence rule.
2. Keep one stamp and one boundary per scope; do not alter nested
   strip-then-restore semantics.
3. Decide and document zero-trigger and proxy-plus-value behavior before public
   release.

This is a good fit because it solves the observed NumPath-style use case without
changing the library's core transaction model. The cost is mostly a contained
refactor of `AnimationScope` internals plus targeted tests. The riskiest part is
not the stamp model; it is defining and verifying the ordering semantics users
will rely on when several triggers change together.

## Open Design Questions

1. Should `.scopeAnimation(_:value:)` be available only on `AnimationScope`, or
   should a general `View` extension be supported later?
2. Should `AnimationScope(name:)` without any `.scopeAnimation` calls be allowed
   and documented as a named boundary?
3. Is "later trigger wins" the right simultaneous-change rule after empirical
   verification?
4. Should triggers have optional names for future diagnostics, or is the scope
   name enough?
5. How should proxy-driven and value-driven triggers resolve when both affect
   the same update pass?
6. Can the runtime trigger application avoid `AnyView` while still supporting an
   ordered list of erased values?
7. Should the existing single-trigger initializer be documented explicitly as
   sugar over `.scopeAnimation(_:value:)`, or left as the primary beginner API?
8. Should `crossScopeAnimationStrip` mention the new API directly once it exists,
   or should that guidance stay in README and DocC only?
9. Does strict concurrency require additional annotations for the internal
   erased trigger value storage?
