# ScopedAnimation

Add structural boundaries to SwiftUI animation.

## Overview

ScopedAnimation is a small SwiftUI library for making animation ownership visible in code and in DEBUG builds. It does three things:

- strips incoming animation transactions at explicit boundaries,
- stamps transactions created by an `AnimationScope`, and
- reports unstamped animation transactions during DEBUG diagnostics.

It does not promise total animation containment. SwiftUI's `withAnimation` still updates every view that reads changed state. ScopedAnimation gives you a practical model for blocking incoming animation at subtree boundaries and detecting unscoped animation while you work.

```swift
AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
  CardContent(isExpanded: isExpanded)
}
```

```swift
AnimationScope(.snappy, name: "Panel") { scope in
  Button("Toggle") {
    scope.animate {
      isExpanded.toggle()
    }
  }
}
```

## Topics

### Start Here

- <doc:GettingStarted>
- <doc:Composition>
- <doc:HowItWorks>
- <doc:PerformancePlaybook>

### Core API

- ``AnimationScope``
- ``AnimationScopeProxy``
