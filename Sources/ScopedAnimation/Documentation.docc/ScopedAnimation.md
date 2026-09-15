# ScopedAnimation

Declare structural boundaries for SwiftUI animation.

## Overview

ScopedAnimation makes animation ownership visible through three operations:

- boundaries remove incoming animation;
- scopes supply animation with an ownership stamp; and
- DEBUG tools report unstamped transactions and draw scope outlines.

Use a value-driven scope to animate a subtree when a value changes:

```swift
AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
    CardContent(isExpanded: isExpanded)
}
```

Use multiple triggers when several values control the same subtree, or a proxy
when an explicit action determines which state changes animate.

State changes still update every view that reads them. A proxy transaction can
reach views outside declared boundaries, and a raw animation modifier can create
animation below a detector. Scopes and barriers provide blocking and detection
at declared locations.

## Topics

### Guides

- <doc:GettingStarted>
- <doc:Composition>
- <doc:HowItWorks>
- <doc:PerformancePlaybook>

### Scope API

- ``AnimationScope``
- ``AnimationTrigger``
- ``AnimationScopeProxy``
