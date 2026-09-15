# Composition

Match each scope to the subtree that owns its animation.

## Separate Visual Layers

Use sibling scopes when different values control separate visual layers.

```swift
VStack(spacing: 12) {
    AnimationScope(.easeOut(duration: 0.12), value: selectedID, name: "Selection") {
        SelectionLayer(selectedID: selectedID)
    }

    AnimationScope(.spring(duration: 0.35), value: hintID, name: "Hint") {
        HintLayer(hintID: hintID)
    }
}
```

Each boundary rejects animation from the other scope while its own value changes
supply local animation.

## Several Values in One Subtree

Declare all value triggers in the scope that owns the content.

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

The first changed array position wins when values change together. Put the
primary motion first. A DEBUG `multiTriggerConflict` warning identifies the
selected and ignored triggers.

## Independent Descendant Regions

Nest scopes when a descendant needs its own animation boundary. The descendant
strips ancestor animation and supplies its own when eligible. Nesting therefore
does not combine several triggers over the same subtree.

A DEBUG `crossScopeAnimationStrip` warning names the scopes involved. Check
whether the descendant should be independent, whether separate visual layers
need sibling scopes, or whether the same subtree needs multiple triggers.

## Stable Layout Slots

Reserve space with ordinary SwiftUI layout and apply a barrier to the content
that rejects incoming animation.

```swift
ZStack {
    AdBannerView()
        .animationBarrier()
}
.frame(height: 50)
```

The frame reserves height. The barrier strips incoming animation within the
banner. Ancestor layout can still move the slot, and a downstream animation
modifier can still generate local animation.

A scope beneath a barrier remains functional: the barrier preserves stamps for
matching proxy scopes, and value-driven scopes can supply their own animation.

## Review Raw Animation Sources

Apps can adopt a policy that animation goes through scopes, with documented
exceptions. Review both `withAnimation` and SwiftUI's view animation modifiers.

Text searches for `.animation(` also match the supported
`AnimationTrigger.animation(_:value:)` factory. Treat search results as review
candidates; a static rule must distinguish those uses before rejecting code.
Runtime detectors complement review but cannot see animation created below their
installation point.

## Adopt a Screen

1. Place `detectAnimationLeaks()` near the screen root.
2. Give each intended animated subtree a scope.
3. Add barriers to regions that must reject incoming animation.
4. Enable the overlay and exercise value changes, proxy actions, and nested regions.
5. Resolve warnings according to the intended ownership.

Check shared state explicitly. A state mutation can invalidate views outside its
animation scope, and a proxy's original transaction can reach regions without a
boundary.
