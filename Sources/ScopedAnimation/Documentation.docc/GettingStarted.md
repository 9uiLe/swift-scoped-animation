# Getting Started

Declare an animation owner, then inspect its boundary.

## Animate a Value Change

Use a value-driven scope when a value determines whether content should animate.

```swift
import ScopedAnimation
import SwiftUI

struct ExpandableCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Button("Toggle details") {
                isExpanded.toggle()
            }

            AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
                VStack(alignment: .leading) {
                    Text("Revenue")
                    if isExpanded {
                        Text("Monthly details")
                            .transition(.opacity)
                    }
                }
            }
        }
    }
}
```

The scope removes incoming ancestor animation. A change to `isExpanded` supplies
the scope's animation to the content update.

## Choose Among Several Values

Use multiple triggers when one subtree has several animation conditions.

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

The first changed trigger wins when values change together. DEBUG diagnostics
report the ignored changes. Keep the trigger count and order stable; see
<doc:HowItWorks> for dynamic-array behavior.

## Animate an Explicit Action

Use a proxy when an action determines which state changes should animate.

```swift
AnimationScope(.snappy, name: "Disclosure") { scope in
    VStack {
        Button("Toggle") {
            scope.animate {
                isOpen.toggle()
            }
        }
        DisclosureContent(isOpen: isOpen)
    }
}
```

Override the default animation for one synchronous action:

```swift
scope.animate(.spring(duration: 0.45)) {
    selection = nextSelection
}
```

The proxy stamps a transaction that can reach other views reading the changed
state. Those regions need their own scope or barrier to reject its animation.

## Block Incoming Animation

```swift
LegacyDashboard()
    .animationBarrier()
```

A barrier strips incoming animation while retaining stamps for descendant scopes.
It also reports unstamped incoming animation in DEBUG. Silence that warning for
intentional legacy traffic with `animationBarrier(warnsOnLeaks: false)`.

## Inspect the Screen

```swift
RootView()
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
```

The detector reports unstamped animation passing through that point. The overlay
shows scope bounds and names. Both compile out of RELEASE builds.

A root detector cannot see raw value animation generated below it. Put a detector
downstream of a suspicious source when investigating that case. Continue with
<doc:Composition> for ownership patterns and <doc:PerformancePlaybook> for cost
and profiling guidance.
