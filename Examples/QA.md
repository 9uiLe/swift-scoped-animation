# ScopedAnimation Example QA

Manual QA is performed on the iOS simulator unless noted otherwise.

## Environment

- Date: 2026-07-03
- Device: iPhone 17 Simulator
- OS: iOS 26.5
- App: `Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj`
- Build:
  `xcodebuild build -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj -scheme ScopedAnimationExample -destination 'platform=iOS Simulator,name=iPhone 17'`

## Checklist

| Area | Steps | Expected Result | Result |
| --- | --- | --- | --- |
| Before / After | Open Compare, tap `Raw update`, then tap `Scoped update`. | The raw panel animates unrelated status UI; the scoped panel animates the card while the status UI stays still. | Not run in this pass. |
| Overlay | Open Overlay, tap `Scoped`, then tap `Raw`. | Scope outlines and labels are visible; raw animation can be detected by the leak detector in DEBUG. | Not run in this pass. |
| List scope propagation | Open List QA, select `Scope`, tap `Run selected`. | Row content receives scoped animation when `AnimationScope` wraps `List`. | Pass |
| List barrier | Open List QA, select `Barrier`, tap `Run selected`. | Row content does not receive animation from the raw parent transaction. | Pass |
| List reuse | Open List QA, select `Reuse`, tap `Run selected`; scroll offscreen and back before the second pulse. | Rows that leave and re-enter the viewport still receive scoped animation. | Pass |

## M3 List QA Result

Command sequence:

```sh
xcodebuild build -quiet \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/ScopedAnimationExampleDerivedData

xcrun simctl install booted \
  .build/ScopedAnimationExampleDerivedData/Build/Products/Debug-iphonesimulator/ScopedAnimationExample.app

xcrun simctl launch booted dev.scopedanimation.example --screen=list-qa --auto-list-qa
xcrun simctl io booted screenshot .build/list-qa-auto.png
```

Observed screen state after the automatic List QA run:

| Check | Observed State | Result |
| --- | --- | --- |
| `AnimationScope` wrapping `List` | `Scope` displayed `Pass`, with `6/12` animated/observed row transactions. | Pass |
| `animationBarrier()` in rows | `Barrier` displayed `Pass`, with `0/6` animated/observed row transactions. | Pass |
| Cell reuse after scroll away/back | `Reuse` displayed `Pass`, with `7/7` animated/observed row transactions after the return pulse. | Pass |

Conclusion: `List` row content received scoped transactions, `animationBarrier()` stripped raw incoming animation inside rows, and scoped behavior survived row reuse in this simulator run.
