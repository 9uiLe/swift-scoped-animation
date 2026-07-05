# Composition

Build scopes around ownership, not around convenience.

## Prefer Sibling Scopes

Use sibling scopes when different triggers affect different visual layers. Each
scope owns one subtree and one animation trigger.

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

Do not nest scopes to put multiple `(animation, value)` pairs on the same
subtree. Descendant scopes strip ancestor scoped animations. In DEBUG builds,
`crossScopeAnimationStrip` reports that composition because the inner boundary
removed another scope's stamped animation.

When two triggers truly affect the same view tree, choose one owner, split the
visual layers into siblings if possible, or leave a small documented
`.animation(_:value:)` exception until a multi-trigger API exists.

## Reserve Static Slots

Use ordinary SwiftUI layout to reserve space, then use `animationBarrier()` to
block incoming animation inside the slot.

```swift
ZStack {
  AdBannerView()
    .animationBarrier()
}
.frame(height: 50)
```

The fixed frame is the layout contract. The barrier is the animation contract:
incoming parent animations are stripped before they reach the banner content.
This is useful for ad banners, embedded controllers, and other static regions
where nearby clear, selection, or hint animations must not cause visual drift.

## Add A Static Check

For apps that want to route animation through scopes, use a blunt CI check until
the planned SwiftLint rule exists. Keep intentional exceptions explicit by
placing `animation-exception:` on the same line.

```sh
violations="$(
  rg -n '(withAnimation|\.animation)\s*\(' --glob '*.swift' . \
    | rg -v 'animation-exception:' \
    || true
)"

if [ -n "$violations" ]; then
  printf '%s\n' "$violations"
  exit 1
fi
```

Use this check for app code, not as a claim that every animation leak can be
detected statically. SwiftUI can create raw value-driven animation transactions
below a root detector, so runtime diagnostics and review still matter.

## Adopt One Screen At A Time

Small apps do not need a large migration plan. Start with one screen:

1. Add `detectAnimationLeaks()` near the screen root in DEBUG builds.
2. Wrap the smallest subtree that should animate in `AnimationScope`.
3. Put `animationBarrier()` around static legacy, ad, or hosting slots.
4. Run the interaction and resolve warnings before moving to the next screen.

The practical goal is visibility: new unscoped animation should be noisy during
development, and each intended animation should have a small structural owner.
