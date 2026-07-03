# Getting Started

Use scopes around the smallest subtree that should animate.

## Add a Value-Driven Scope

Use a value-driven scope when animation should be tied to one state value.

```swift
import ScopedAnimation
import SwiftUI

struct Card: View {
  @State private var isExpanded = false

  var body: some View {
    AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
      VStack(alignment: .leading) {
        Text("Revenue")
        DetailRows(isExpanded: isExpanded)
      }
    }
  }
}
```

The scope strips incoming animation from ancestors, then lets the scoped value change animate inside the subtree.

## Use a Proxy for Explicit Triggers

Use the proxy-driven initializer when only a specific action should animate.

```swift
AnimationScope(.easeInOut(duration: 0.25), name: "Disclosure") { scope in
  DisclosureContent(isOpen: isOpen)
    .onTapGesture {
      scope.animate {
        isOpen.toggle()
      }
    }
}
```

You can override the animation for one trigger.

```swift
scope.animate(.spring(duration: 0.45)) {
  selection = nextSelection
}
```

## Block Legacy Subtrees

Use `animationBarrier()` around UI that should ignore incoming animation.

```swift
LegacyDashboard()
  .animationBarrier()
```

In DEBUG builds, the barrier also reports unstamped animation transactions that it strips. Pass `warnsOnLeaks: false` when the barrier intentionally silences legacy animation noise.

```swift
LegacyDashboard()
  .animationBarrier(warnsOnLeaks: false)
```

## Add Diagnostics

Place `detectAnimationLeaks()` near a screen root, or on a suspicious subtree.

```swift
RootView()
  .detectAnimationLeaks()
```

Add the overlay while tuning scope placement.

```swift
RootView()
  .animationScopeDebugOverlay()
```

Diagnostics are compiled out in RELEASE builds.
