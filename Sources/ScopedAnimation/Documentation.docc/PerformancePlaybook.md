# Animation Performance Playbook

Keep animated subtrees small and predictable.

## Scope the Smallest Useful Subtree

Animation cost generally grows with the number of views that react to the transaction. Put `AnimationScope` around the content that should move, not around the whole screen.

```swift
VStack {
  Header()

  AnimationScope(.smooth, value: isExpanded, name: "Card body") {
    CardBody(isExpanded: isExpanded)
  }

  Footer()
}
```

Use `animationBarrier()` around unrelated UI that should remain static when parent state changes.

## Prefer Cheap Visual Properties

Prefer animating properties that usually avoid broad layout work:

- `opacity`
- `scaleEffect`
- `offset`
- `rotationEffect`

Be careful with properties that can cause wider layout invalidation or expensive rendering:

- `frame`
- `padding`
- `font`
- large `blur`
- large or animated `shadow`

These are not forbidden. They just deserve measurement when used in repeated rows, complex screens, or frequent interactions.

## Measure With Instruments

Use Instruments when an animation feels slow. Pick the template for the target
you are measuring:

- On a physical iPhone or iPad, or when profiling a macOS app on the host Mac,
  use the SwiftUI template so the SwiftUI instrument lane is populated.
- On the iOS Simulator, use Time Profiler. The simulator does not populate the
  SwiftUI lane, and its host-driven rendering is not representative of device
  performance. Use it for functional checks and CPU, hang, or hitch clues, not
  final rendering sign-off.

1. Run the sample or your app on the chosen target.
2. Open Instruments and select the template above.
3. Trigger the animation repeatedly.
4. Compare the animated subtree before and after moving a scope or barrier.

ScopedAnimation encourages scoping discipline. It does not make performance claims about a particular frame rate or rendering cost.
