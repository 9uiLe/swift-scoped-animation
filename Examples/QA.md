# Example app QA

Use the iOS sample to inspect behavior that hosted transaction tests cannot
establish: rendered motion, List row propagation and reuse, overlay placement,
and interactive controls.

## Run the app

Build `Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj` with the
`ScopedAnimationExample` scheme and an available iPhone simulator. Use a DEBUG
build to inspect runtime warnings and outlines.

Record the date, source revision, Xcode version, device, runtime, steps, and
observed result for every QA run. Recheck on major OS or Xcode changes.

## Procedure

| Area | Steps | Expected result |
| --- | --- | --- |
| Compare | Tap `Raw update`, then `Scoped update`. | The raw panel animates unrelated status UI. The scoped panel animates its card while adjacent status UI updates without that animation. |
| Overlay | Tap `Scoped`, then `Raw`. Scroll or resize as applicable. | Named outlines follow the scope bounds. The raw action exercises the detector. Outlines do not intercept interaction or accessibility navigation. |
| List scope propagation | Select `Scope` and tap `Run selected`. | Visible row transactions carry scoped animation; the status reports animated and observed counts. |
| List barrier | Select `Barrier` and run it. | Rows are observed but carry no raw incoming animation. Zero observed rows are not a passing result. |
| List reuse | Select `Reuse`, run it, and scroll rows out of view and back before the return pulse. | Reappearing rows receive scoped animation. |
| List run controls | Start a run and inspect the controls; leave the screen during a run and return. | Conflicting runs are disabled. Leaving cancels pending work without publishing partial success. |
| Multi-Trigger selection | Tap board cells. | Selection animates with the first trigger's ease-out animation. |
| Multi-Trigger hints | Tap `Show hints`. | Hints animate with the spring while selection remains unchanged. |
| Multi-Trigger conflict | Tap `Select + hint together`. | The first trigger wins for the update and DEBUG reports `multiTriggerConflict`. |
| Multi-Trigger reset | Tap `Reset`. | Both sets clear without stale visual state. |

## Recorded observations: 2026-07-14

Environment: iPhone 17 Simulator, iOS 26.5,
UDID `5A6604DB-0328-4DFD-89EF-6A5EEE0CE974`.
The source revision was not recorded. These observations do not certify every
subsequent source state.

| Check | Recorded observation | Result |
| --- | --- | --- |
| Compare | Raw status UI visibly animated; the scoped card animated while adjacent status UI updated without visible animation. | Pass |
| Overlay | The outline and `Outer` label rendered; the raw probe exercised the detector placement. | Pass |
| List scope | `Scope` displayed `Pass`, with 6/6 animated/observed row transactions. | Pass |
| List barrier | `Barrier` displayed `Pass`, with 0/6 animated/observed row transactions. | Pass |
| List reuse | `Reuse` displayed `Pass`, with 7/7 animated/observed row transactions after the return pulse. | Pass |
| List run controls | No manual result recorded. | Unverified |
| Multi-Trigger interactions | No manual result recorded. | Unverified |

The List run used `--screen=list-qa --auto-list-qa`. The overlay run used
`--screen=overlay --auto-overlay-qa`. Compare buttons were activated through
accessibility controls.

Local screenshot paths recorded for that run were `.build/list-qa-auto.png`,
`.build/before-after-qa.png`, and `.build/overlay-qa.png`. These are local build
artifacts, not distributed evidence files.

## Coverage limits

- Unit-hosted List row hooks may not execute; use the sample's row counters.
- Animated transaction counts do not prove smooth rendering.
- A successful example build does not count as manual QA.
- Physical-device behavior requires a recorded run on the relevant device.

Automated test and build output is recorded in [validation](../docs/validation.md).
