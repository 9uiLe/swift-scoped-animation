# ScopedAnimation

Structural boundaries and DEBUG diagnostics for SwiftUI animation.

<p align="center">
  <a href="https://github.com/9uiLe/swift-scoped-animation/actions/workflows/ci.yml"><img src="https://github.com/9uiLe/swift-scoped-animation/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://swiftpackageindex.com/9uiLe/swift-scoped-animation"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-scoped-animation%2Fbadge%3Ftype%3Dswift-versions" alt="Swift versions"></a>
  <a href="https://swiftpackageindex.com/9uiLe/swift-scoped-animation"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-scoped-animation%2Fbadge%3Ftype%3Dplatforms" alt="Platforms"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <img src="docs/assets/overlay-hero.gif" alt="ScopedAnimation debug overlay showing named animation scopes" width="640">
</p>

<p align="center">
  <img src="docs/assets/compare-demo.gif" alt="Before and After comparison demo" width="310">
  <img src="docs/assets/list-qa-demo.gif" alt="List QA propagation and barrier demo" width="310">
</p>

ScopedAnimation makes animation ownership visible in the view tree. Scopes and
barriers remove incoming animation, scopes stamp the animation they supply, and
DEBUG diagnostics report unstamped transactions at observation points.

State changes still reach every view that reads them. A proxy transaction can
also animate views outside declared boundaries. Place scopes or barriers around
regions that must reject incoming animation.

## Requirements and installation

- iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+
- Swift 6 language mode; package manifest requires Swift tools 6.2+
- Swift Package Manager; no external dependencies

Add this URL in Xcode:

```text
https://github.com/9uiLe/swift-scoped-animation.git
```

Or declare the package and add `ScopedAnimation` to your target's dependencies:

```swift
.package(url: "https://github.com/9uiLe/swift-scoped-animation.git", from: "0.2.1")
```

## Choose the animation owner

| Need | API |
| --- | --- |
| Animate a subtree when one value changes | `AnimationScope(_:value:name:content:)` |
| Choose among several value triggers for one subtree | `AnimationScope(name:triggers:content:)` |
| Animate state changes in an explicit action | `AnimationScope(_:name:content:)` with a proxy |
| Remove incoming animation without supplying one | `animationBarrier(warnsOnLeaks:)` |

### One value

```swift
import ScopedAnimation
import SwiftUI

AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
    CardContent(isExpanded: isExpanded)
}
```

The boundary strips ancestor animation. A change to `isExpanded` supplies the
scope's animation to its content.

### Several values

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

When several values change together, the first changed trigger in the array
wins. DEBUG builds report the ignored changed triggers.

Values compare by concrete type and equality. Changing only an animation does
not trigger motion. Keep the array's count and order stable: resizing establishes
a new baseline without animation, and reordering compares values by position.
Content identity and local state survive count changes.

### An explicit action

```swift
AnimationScope(.snappy, name: "Disclosure") { scope in
    Button("Toggle") {
        scope.animate {
            isOpen.toggle()
        }
    }
}
```

Use `scope.animate(.spring(duration: 0.4)) { ... }` to override the animation for
one synchronous action. The proxy stamps the transaction; a matching boundary
can restore it after an ancestor scope or barrier strips its animation.

### A barrier

```swift
LegacyDashboard()
    .animationBarrier()
```

The barrier removes incoming animation and preserves stamps for descendant
scopes. Pass `warnsOnLeaks: false` to silence its DEBUG warning for intentionally
blocked legacy traffic.

A barrier does not reserve layout space or stop a descendant SwiftUI animation
modifier from generating its own transaction. Use ordinary layout, such as a
fixed frame, when a region also needs stable dimensions.

## Compose scopes

Use sibling scopes for separate visual layers. Use several triggers in one scope
when multiple values affect the same subtree.

Every nested scope is an independent boundary. It strips its ancestor's animation
and supplies its own only when a local trigger changes or its proxy stamp matches.
DEBUG `crossScopeAnimationStrip` warnings identify cross-scope stripping;
`multiTriggerConflict` warnings identify competing values within one scope.

An empty trigger array creates a named boundary that appears in the DEBUG overlay.
Use `animationBarrier()` when a name is unnecessary.

## Inspect animation ownership

```swift
RootView()
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
```

Detectors report animation-bearing transactions without a scope stamp. The
overlay draws named scope boundaries. Both compile out of RELEASE builds.

| Source | Root detector | Detector or barrier downstream of the source |
| --- | --- | --- |
| Raw `withAnimation` or animated, unstamped `withTransaction` | Detects passing transactions | Detects passing transactions |
| Raw `.animation(_:value:)` below the root detector | Cannot observe animation created below it | Detects passing transactions |
| Stamped transaction | Does not report a leak | Does not report a leak |

Start at a screen root, then place detectors on suspicious subtrees and barriers
around regions that reject incoming animation. Review raw animation calls because
runtime observation is limited by placement. Any static rule must distinguish
SwiftUI view animation modifiers from the supported `AnimationTrigger.animation`
factory.

## Performance and compatibility

Small scopes make the intended animated subtree explicit. They do not prevent
state invalidation or guarantee fewer body evaluations.

Trigger equality, trigger construction, and DEBUG diagnostics have costs.
Use small values when they fully describe the animation condition. The
[Performance Playbook](Sources/ScopedAnimation/Documentation.docc/PerformancePlaybook.md)
covers application profiling; [reference measurements](docs/performance.md)
describe internal CPU costs and their limits.

Transaction propagation is observed SwiftUI behavior. The automated suite checks
macOS and iOS hosting. `List` row propagation and cell reuse require the
[sample QA procedure](Examples/QA.md), with recorded results tied to specific
environments. Recheck compatibility when adopting a new major Xcode or OS release.

## Example app

The sample contains Compare, Overlay, List QA, and Multi-Trigger screens.

```sh
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Documentation

- [Getting Started](Sources/ScopedAnimation/Documentation.docc/GettingStarted.md):
  complete usage examples.
- [Composition](Sources/ScopedAnimation/Documentation.docc/Composition.md):
  sibling scopes, nested ownership, and static layout slots.
- [How It Works](Sources/ScopedAnimation/Documentation.docc/HowItWorks.md):
  transactions, stamps, value resolution, and diagnostic placement.
- [Design](HANDOFF.md): product contracts, internal architecture, and roadmap.
- [Contributing](CONTRIBUTING.md): repository map and required checks.
- [Validation](docs/validation.md): tested environments, command output, and limits.

Build DocC with Xcode:

```sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS'
```

The package does not require `swift-docc-plugin`.

## License

MIT. See [LICENSE](LICENSE).
