# Phase 0 Spike Findings

Date: 2026-07-03  
Toolchain: Xcode 26.5 (17F42), Apple Swift 6.3.2  
Runtime: iPhone 17 simulator, iOS 26.5  
Spike code: `spike/` SwiftPM package, intentionally ignored by git

## Summary

| ID | Verdict | Finding |
|---|---|---|
| S1 | Works | `.transaction { $0.animation = nil }` strips both ancestor `withAnimation` transactions and ancestor implicit `.animation(_:value:)` transactions before they reach descendants. |
| S2 | Works | A descendant `.animation(_:value:)` placed inside the barrier reintroduces animation only for its own `value` changes. Ancestor value-driven animation remains stripped. |
| S3 | Conditional | `TransactionKey` stamps created with `withTransaction` propagate to root and descendants. Stamps can be injected into `.animation(_:value:)` transactions for downstream descendants, but that stamped transaction does not travel upward to a root `.transaction {}` observer. |
| S4 | Conditional | A root `.transaction {}` hook can observe global `withAnimation` leaks at practical call counts, but it is blind to descendant `.animation(_:value:)` transactions created below the root observer. |
| S5 | Conditional | `.transition` and `matchedGeometryEffect` work inside a barrier when a local value animation is reapplied. `LazyVStack` rows and `List` container updates did not receive animation through the barrier. `List` row hooks were not invoked in this unit-hosting harness, so List cell reuse needs Phase 1 sample/manual QA coverage. |
| S6 | Works | Anchor preference overlay frames update during scroll and resize. |
| S8 | Works | `.transaction(value:)` transforms the transaction for its tracked value change and does not add animation to an unrelated state update. This gates the structurally stable multi-trigger resolver. |

## Go / No-Go

Go for Phase 1 with one required design clarification before implementation:

- Value-driven scope stamping is downstream-only. It can mark the scoped subtree, but a root leak detector cannot rely on seeing those value-driven stamps.
- Leak detection should be documented and implemented as high confidence for `withAnimation` / explicit `withTransaction` leaks, and lower precision for descendant implicit `.animation(_:value:)` leaks.

This is not a Phase 1 implementation. No library code was created.

## Test Command

```sh
xcodebuild test -scheme SwiftAnimationSpike -destination 'platform=iOS Simulator,name=iPhone 17'
```

Focused output excerpt:

```text
S1_EXPLICIT: seq=1 label=explicit-barrier animation=false stamp=nil disables=false | seq=2 label=explicit-control animation=true stamp=nil disables=false
S1_IMPLICIT: seq=3 label=implicit-barrier animation=false stamp=nil disables=false | seq=4 label=implicit-control animation=true stamp=nil disables=false
S2_OUTER: seq=1 label=s2 animation=false stamp=nil disables=false
S2_INNER: seq=2 label=s2 animation=true stamp=nil disables=false
S3_WITH_TRANSACTION: seq=1 label=root animation=true stamp=with-transaction disables=false | seq=2 label=with-transaction-child animation=true stamp=with-transaction disables=false
S3_VALUE_STAMP: seq=3 label=root animation=false stamp=nil disables=false | seq=4 label=value-child animation=true stamp=value-driven disables=false
S4_METRICS rootCalls=5 rowCalls=300 elapsedMs=206.62
S4_IMPLICIT_DESCENDANT: seq=306 label=root animation=false stamp=nil disables=false | seq=307 label=implicit-descendant animation=true stamp=nil disables=false
S5_TRANSITION: seq=2 label=list-container animation=false stamp=nil disables=false | seq=3 label=transition-container animation=true stamp=nil disables=false
S5_LIST_LAZY_COUNTS listContainer=1 listRows=0 lazyRows=10 listAnimated=0 lazyAnimated=0
S6_GEOMETRY: #0:16.0,1472.0,358.0,44.0 #1:16.0,146.0,358.0,44.0 #2:16.0,146.0,812.0,44.0
TEST SUCCEEDED
```

## S1: Barrier Strips Incoming Animation

Verdict: Works.

Minimal reproduction:

```swift
Text("explicit-barrier")
    .opacity(model.flag ? 0.25 : 1)
    .transaction { recorder.record("explicit-barrier", $0) }
    .transaction { $0.animation = nil }

Text("implicit-barrier")
    .opacity(model.inner ? 0.25 : 1)
    .transaction { recorder.record("implicit-barrier", $0) }
    .transaction { $0.animation = nil }
    .animation(.linear(duration: 0.2), value: model.inner)
```

Trigger:

```swift
withAnimation(.linear(duration: 0.2)) {
    model.flag.toggle()
}

model.inner.toggle()
```

Observed behavior:

- Explicit control saw `animation=true`; explicit barrier saw `animation=false`.
- Implicit control saw `animation=true`; implicit barrier saw `animation=false`.

## S2: Reapply Value Animation Inside Barrier

Verdict: Works.

Minimal reproduction:

```swift
Text("s2")
    .opacity(model.inner ? 0.25 : 1)
    .scaleEffect(model.outer ? 1.2 : 1)
    .transaction { recorder.record("s2", $0) }
    .animation(.snappy(duration: 0.2), value: model.inner)
    .transaction { $0.animation = nil }
    .animation(.linear(duration: 0.2), value: model.outer)
```

Observed behavior:

- `model.outer.toggle()` produced `animation=false`.
- `model.inner.toggle()` produced `animation=true`.

Modifier order matters: the barrier must sit outside the scoped value animation and inside any ancestor animation source.

## S3: TransactionKey Stamping

Verdict: Conditional.

Minimal reproduction:

```swift
private enum SpikeStampKey: TransactionKey {
    static let defaultValue: String? = nil
}

private extension Transaction {
    var spikeStamp: String? {
        get { self[SpikeStampKey.self] }
        set { self[SpikeStampKey.self] = newValue }
    }
}
```

`withTransaction` stamping:

```swift
var transaction = Transaction(animation: .linear(duration: 0.2))
transaction.spikeStamp = "with-transaction"
withTransaction(transaction) {
    model.flag.toggle()
}
```

Value-driven stamping:

```swift
Text("value-stamped")
    .opacity(model.inner ? 0.2 : 1)
    .transaction { recorder.record("value-child", $0) }
    .transaction {
        if $0.animation != nil {
            $0.spikeStamp = "value-driven"
        }
    }
    .animation(.linear(duration: 0.2), value: model.inner)
```

Observed behavior:

- `withTransaction` stamp reached both root and child: `stamp=with-transaction`.
- Value-driven stamp reached the child: `label=value-child animation=true stamp=value-driven`.
- The root observer saw the same value-driven update as `animation=false stamp=nil`.

Implication: value-driven scope stamping can support scoped descendant diagnostics, but root-level leak detection cannot precisely identify those transactions.

## S4: Root Leak Observation

Verdict: Conditional.

Minimal reproduction:

```swift
VStack(spacing: 4) {
    ForEach(0..<60, id: \.self) { index in
        Text("row-\(index)")
            .opacity(model.flag ? 0.4 : 1)
            .transaction { recorder.record("row", $0) }
    }

    Text("implicit-descendant")
        .opacity(model.inner ? 0.4 : 1)
        .transaction { recorder.record("implicit-descendant", $0) }
        .animation(.linear(duration: 0.2), value: model.inner)
}
.transaction { recorder.record("root", $0) }
```

Observed behavior:

- Five `withAnimation` toggles produced `rootCalls=5` and `rowCalls=300`.
- The elapsed measurement for the five toggles plus run-loop pumping was about 206 ms in the simulator test harness.
- For a descendant value-driven `.animation(_:value:)`, root saw `animation=false`, while the descendant saw `animation=true`.

Implication: root observation is practical for global animation leaks but incomplete for descendant implicit animations.

## S5: Transition, Matched Geometry, List, LazyVStack

Verdict: Conditional.

Minimal reproduction:

```swift
VStack {
    if model.show {
        Text("transition")
            .transition(.opacity.combined(with: .scale))
    }
}
.transaction { recorder.record("transition-container", $0) }
.animation(.snappy(duration: 0.2), value: model.show)
.transaction { $0.animation = nil }

HStack {
    // Either side contains a matchedGeometryEffect view.
}
.transaction { recorder.record("matched-geometry", $0) }
.animation(.easeInOut(duration: 0.2), value: model.swap)
.transaction { $0.animation = nil }

List(model.items, id: \.self) { item in
    Text("list-\(item)")
        .transaction { recorder.record("list-row", $0) }
}
.transaction { recorder.record("list-container", $0) }
.transaction { $0.animation = nil }

ScrollView {
    LazyVStack {
        ForEach(model.items, id: \.self) { item in
            Text("lazy-\(item)")
                .transaction { recorder.record("lazy-row", $0) }
        }
    }
}
.transaction { $0.animation = nil }
```

Observed behavior:

- Local value animations restored `.transition` and `matchedGeometryEffect` inside the barrier.
- Barrier stripped animation from `List` container updates and `LazyVStack` rows.
- `List` row transaction hooks were not called in this unit-hosted test (`listRows=0`), so this spike did not prove row-level List cell reuse behavior.
- No crash or broken update was observed for the hosted List/LazyVStack mutation.

## S6: Anchor Preference Overlay Tracking

Verdict: Works.

Minimal reproduction:

```swift
Text("overlay-row-\(index)")
    .anchorPreference(
        key: OverlayAnchorPreferenceKey.self,
        value: .bounds
    ) { anchor in
        index == 28 ? ["tracked": anchor] : [:]
    }

.overlayPreferenceValue(OverlayAnchorPreferenceKey.self) { anchors in
    GeometryReader { proxy in
        let frames = anchors.mapValues { proxy[$0] }
        Color.clear.preference(key: OverlayFramePreferenceKey.self, value: frames)
    }
}
.onPreferenceChange(OverlayFramePreferenceKey.self) { frames in
    recorder.record(frames)
}
```

Observed behavior:

- Initial tracked frame: `x=16.0 y=1472.0 width=358.0 height=44.0`.
- After scrolling to the tracked row: `x=16.0 y=146.0 width=358.0 height=44.0`.
- After resizing to a landscape-sized host: `x=16.0 y=146.0 width=812.0 height=44.0`.

The overlay follows scroll position and host-size changes.

## S8: Value-Gated Transaction Resolver

Verdict: Works.

The library test `testS8ValueTransactionHookOnlyAnimatesItsTrackedValue` hosts a
view with one tracked value and one unrelated value. Both affect the same child,
but only the tracked value is passed to `.transaction(value:)`.

Command:

```sh
swift test --filter testS8ValueTransactionHookOnlyAnimatesItsTrackedValue
```

Observed output on 2026-07-14 with the repository toolchain:

```text
S8_VALUE_TRANSACTION_UNRELATED: ... animation=false ...
S8_VALUE_TRANSACTION_TRACKED: ... animation=true ...
Executed 1 test, with 0 failures (0 unexpected)
```

Implication: one stable resolver modifier can gate animation by the complete
trigger snapshot, while resolving the changed array positions explicitly rather
than stacking `.animation(_:value:)` modifiers.

## Required HANDOFF.md Updates Before Phase 1

1. Revise S3-dependent semantics: value-driven scope stamping is downstream-only, not root-observable.
2. Revise leak detection scope: root leak detection is reliable for global `withAnimation` / explicit `withTransaction` leaks, but descendant `.animation(_:value:)` leaks require lower-precision detection or local scoped observers.
3. Add a Phase 1 QA requirement for `List` row reuse, because this spike observed the List container but not row-level transaction hooks in the unit-hosted harness.
