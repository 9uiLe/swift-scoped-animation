# ScopedAnimation design

ScopedAnimation is a SwiftUI library for declaring animation ownership through
view-tree boundaries. This document defines the product scope, public contracts,
internal responsibilities, validation requirements, and roadmap.

Start with [README.md](README.md) for installation and examples. Use
[CONTRIBUTING.md](CONTRIBUTING.md) for build and contribution instructions.

## 1. Product and constraints

An `AnimationScope` declares the subtree that owns an animation. Every boundary
removes incoming animation, and a scope supplies animation through its declared
value triggers or an explicit proxy action. DEBUG diagnostics expose boundaries
and report animation transactions without a scope stamp.

The product provides **blocking and detection**. State changes still invalidate
every view that reads the changed state. Views outside declared boundaries can
receive a proxy's original animation. Raw SwiftUI animation modifiers inside a
boundary can create their own animation downstream.

The library uses SwiftUI's `Animation` and `Transaction`. Its scope excludes:

- custom curves, physics engines, or effect collections;
- UIKit or AppKit animation APIs;
- automatic control of layout cost, frame rate, or state invalidation;
- exhaustive leak detection or static analysis of animated layout properties;
- a SwiftSyntax lint plugin.

Distribution and compatibility:

| Property | Contract |
| --- | --- |
| Repository | `swift-scoped-animation` |
| Product and module | `ScopedAnimation` |
| Distribution | Swift Package Manager only |
| Dependencies | No external package dependencies |
| License | MIT |
| Platforms | iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+ |
| Language | Swift 6 with complete strict concurrency |
| Development toolchain | Xcode 26.x / Swift 6.3 |

The deployment floors support custom `TransactionKey` values and
`.transaction(value:)`. Actual propagation behavior is a compatibility
assumption verified by hosted tests; see
[SwiftUI assumptions](docs/swiftui-assumptions.md).

## 2. Domain model

| Term | Meaning |
| --- | --- |
| Scope | A view container with a stable identity, an animation boundary, and a declared source of animation. |
| Boundary | A transaction hook that removes incoming animation and preserves its stamp. A scope boundary can restore animation from its own stamp. |
| Trigger | An `Equatable` value paired with the animation to use when that value changes. |
| Snapshot | The ordered trigger configuration used for positional value comparison. |
| Resolution | The first changed trigger, plus lower-priority changed triggers in DEBUG. |
| Stamp | Internal transaction metadata containing a scope ID, optional display name, and animation payload. |
| Proxy | An object supplied to scoped content that runs synchronous state changes in a stamped transaction. |
| Leak | An animation-bearing transaction with no scope stamp at a diagnostic observation point. |
| Warning site | A debounce key derived from the warning kind and, where applicable, a scope name. |

A display name is not an identity. A scope keeps the same ID across body
evaluations while its view identity is stable. Names and animation payloads may
change without replacing that ID.

## 3. Public API

### Value-driven scope

```swift
AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
    CardContent(isExpanded: isExpanded)
}
```

The single-value initializer is a one-trigger form of the multi-trigger API:

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

Every trigger is visible in the scope declaration. A single scope has one
boundary and one identity, regardless of the number of triggers.

| Update | Required behavior |
| --- | --- |
| Initial mount | Establish the value baseline without starting a value-driven animation. |
| One or more values change | Select the changed trigger closest to the start of the array. Apply its animation and stamp together. |
| Several values change together | Use the same winner for the whole subtree; report ignored changed triggers in DEBUG. |
| Values remain equal | Do not start a value-driven animation. |
| Only an animation or scope name changes | Do not trigger animation. A subsequent value change uses the current configuration. |
| Trigger count changes | Establish a new baseline without a trigger animation or conflict warning. Preserve content identity and local state. |
| Triggers are reordered | Compare by position; the new positions also determine priority. |
| Concrete value type changes | Treat the value as changed, even if Swift can cast between the two types. |
| `disablesAnimations` is true | Do not apply a value-driven animation or stamp for that resolution. |

Values are type-erased for heterogeneous arrays but are equal only when both
their concrete type and value match. For example, `Int(1)` and
`Optional<Int>.some(1)` are different trigger values. Keep array composition and
order stable when those changes are not part of the intended behavior.

`triggers: []` creates a named boundary with no value-driven animation. It strips
incoming animation, preserves the stamp for descendants, and appears in the
DEBUG overlay. It does not emit a barrier's unstamped-animation warning. Use
`animationBarrier()` when no scope label is needed.

### Proxy-driven scope

```swift
AnimationScope(.snappy, name: "Disclosure") { scope in
    Button("Toggle") {
        scope.animate {
            isOpen.toggle()
        }
    }
}
```

The proxy exposes two synchronous operations:

```swift
scope.animate {
    isOpen.toggle()
}

scope.animate(.spring(duration: 0.4)) {
    selection = nextSelection
}
```

Both create a transaction containing the requested animation and the scope's
stamp, then execute the closure with `withTransaction`. The second form changes
the animation for that call.

The stamped transaction can reach the root and other views that read the
changed state. Declared boundaries determine where its animation is removed or
restored. Place a scope or barrier around unrelated regions that must reject it.

### Standalone barrier

```swift
LegacyDashboard()
    .animationBarrier()
```

A barrier removes incoming animation and preserves the stamp. It never restores
an animation. A descendant scope can still supply its own value-driven animation
or restore a matching proxy stamp.

In DEBUG, the barrier warns when it strips an animation without a stamp.
`animationBarrier(warnsOnLeaks: false)` disables that warning without changing
the boundary behavior. A barrier does not reserve layout space or prevent
downstream SwiftUI modifiers from creating animation.

## 4. Transaction semantics

### Boundary processing

A scope boundary processes every incoming transaction in this order:

1. Read its stamp and, in DEBUG, inspect it for applicable diagnostics.
2. Set `transaction.animation` to `nil`, regardless of stamp ownership.
3. Preserve the stamp so it can reach descendant scopes.
4. Restore the stamp's animation only if its ID matches this scope and
   `transaction.disablesAnimations` is false.

The boundary is outside the value resolver in the modifier chain. SwiftUI
therefore processes the boundary before the resolver supplies local animation.

```text
incoming transaction
        |
        v
boundary: strip animation; preserve stamp; restore matching proxy animation
        |
        v
value resolver: apply selected trigger animation and local stamp when eligible
        |
        v
content, including any descendant boundaries
```

Value-driven stamps are created inside the scope and travel downstream. An
observer above that scope does not see those stamps or its locally supplied
animation. Proxy stamps originate in `withTransaction` and can reach both root
and descendant observers.

### Nested scopes

| Animation source | Outer scope region | Inner scope region |
| --- | --- | --- |
| Outer proxy | Restores the matching outer stamp | Strips the outer animation |
| Inner proxy | Strips the nonmatching inner animation but preserves its stamp | Restores the matching inner stamp |
| Outer value change | Supplies outer animation | Strips outer animation unless an inner trigger supplies its own |
| Outer and inner value changes | Supplies outer animation | Supplies inner animation and stamps inner ownership |

An inner value-driven scope stamps its own update even when its selected
animation compares equal to the outer animation.

Use sibling scopes for separate visual layers. Use multiple triggers in one
scope when several values control the same subtree. Nesting expresses an
independent descendant boundary.

### Transitions

Insertion and removal within scoped content receive the eligible scoped
transaction. Tests verify the supplied animation and stamp. Visual interpolation,
layout behavior, and framework-hosted row reuse require sample-app QA.

## 5. Internal architecture

| Component | Responsibility |
| --- | --- |
| `AnimationScope.swift` | Retain scope identity, adapt content creation, and compose resolver, boundary, and DEBUG overlay registration. Only proxy-driven content receives a proxy. |
| `AnimationTrigger.swift` | Pair an animation with a type-erased value and compare concrete value types before equality. |
| `AnimationTriggerResolution.swift` | Compare snapshots, select trigger priority, and retain pending resolutions across repeated body evaluations. |
| `ValueAnimationResolver.swift` | Gate delivery with `.transaction(value:)` and apply one resolution to animation, stamp, and conflict diagnostics. |
| `AnimationScopeBoundary.swift` | Implement stripping for scopes and barriers, with matching-stamp restoration enabled only for scopes. |
| `AnimationBarrier.swift` | Expose the standalone boundary modifier and its diagnostic option. |
| `AnimationScopeProxy.swift` | Run explicit actions in a transaction containing the scope's stamp and chosen animation. |
| `TransactionStamp.swift` | Define the transaction key and immutable stamp values. Equality and hashing depend on the scope ID. |
| `Diagnostics/` | Observe leaks, render boundary outlines, construct typed warning events, debounce, and emit runtime warnings. |

### Resolver state

All trigger counts use the same modifier structure. Changing the array length
does not replace the content branch.

`AnimationTriggerHistory` is main-actor isolated. One comparison classifies a
snapshot as unchanged, structurally changed, or value changed:

- An unchanged snapshot returns the pending resolution.
- A count change clears the pending resolution and stores the new baseline.
- A value change stores the new snapshot and its resolution.

SwiftUI may evaluate a modifier more than once before delivering its
transaction. Retaining the pending resolution prevents an early evaluation from
consuming the animation. The value gate prevents that retained result from
animating an unrelated update.

A selection pairs an index with its animation. The resolver and diagnostics use
that same selection, so priority and the animation payload cannot drift between
independent calculations. Rejected selections exist only in DEBUG.

## 6. DEBUG diagnostics

### Detection and placement

```swift
RootView()
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
```

A detector sees only transactions passing through its installation point.

| Source at the observation point | Root detector | Downstream detector or barrier sensor |
| --- | --- | --- |
| Unstamped `withAnimation` or animated `withTransaction` | Detects the passing transaction | Detects the passing transaction |
| Raw `.animation(_:value:)` below the root observer | Cannot observe animation created below it | Detects it when downstream of its source |
| Stamped animation | Does not report a leak | Does not report a leak |

Place detectors at screen roots or suspicious subtree boundaries. Automatically
installing them on every row multiplies transaction-hook work. Use barriers
around regions that reject incoming animation, and review raw animation calls
that may generate transactions below observation points.

### Warning contracts

| Event | Condition |
| --- | --- |
| Unscoped animation | A detector observes non-nil animation without a stamp. |
| Barrier leak | A warning-enabled barrier strips non-nil animation without a stamp. |
| `crossScopeAnimationStrip` | A scope strips another scope's animation-bearing stamp while animations are enabled. |
| `multiTriggerConflict` | A value resolution has more than one changed trigger while animations are enabled. |

Warning events carry typed data. Message formatting occurs when an accepted
event's consumer reads the message, after debounce. The default sink uses
`os_log` runtime issues without a package dependency.

Debounce sites use warning kind and, for scope-specific warnings, the scope name.
Empty and absent names share the unnamed site. Different views with the same
kind and name can therefore share a debounce window. The default interval is
one second, with at most 64 stored sites. Expired entries are removed and storage
remains bounded.

The warning state and sink are lock protected. Tests replace them within a
scoped capture operation that restores both on return or throw.

### Overlay and RELEASE behavior

Scopes register bounds through anchor preferences. The overlay resolves those
anchors into dashed outlines and labels, with stable colors derived from IDs.
It follows layout and scroll changes, ignores hit testing, and is hidden from
accessibility navigation.

Diagnostic implementations and rejected-trigger storage are guarded by
`#if DEBUG`. The detector and overlay return the original view in RELEASE.
The release audit checks that diagnostic markers appear in DEBUG artifacts and
are absent from RELEASE artifacts.

## 7. Performance model

Scopes constrain incoming animation; they do not remove state dependencies,
reduce body evaluation by definition, or guarantee a frame rate.

- Trigger comparison cost depends on count and `Equatable` complexity. RELEASE
  history stops at the first changed trigger. DEBUG also collects competing
  changes. Unchanged snapshots require all values to compare equal.
- SwiftUI's value gate compares snapshots separately from history resolution.
- Trigger construction includes array storage and type erasure. Large derived
  values can cost more than scope bookkeeping.
- A proxy scope uses an empty trigger snapshot. A standalone barrier requires
  no trigger history.
- Suppressed warnings avoid message formatting but still perform site lookup,
  locking, and bounded debounce bookkeeping.
- DEBUG overlay work scales with registered boundaries and layout updates.

Keep animated subtrees and trigger values small when that matches the intended
behavior. Measure layout-sensitive properties and expensive effects in the
application. See the [Performance Playbook](Sources/ScopedAnimation/Documentation.docc/PerformancePlaybook.md),
[benchmark method](Benchmarks/README.md), and
[reference measurements](docs/performance.md).

## 8. Validation and compatibility

### Automated contracts

The primary harness records transactions in hosted SwiftUI content on macOS and
iOS. Tests use Swift Testing and a serialized main-actor suite. Each test retains
its host, closes it with `defer`, and pumps the run loop or uses explicit
expectations instead of sleeping.

An absence-of-animation assertion requires an observed transaction. Zero
observations fail the test. Assertions inspect animation values, stamps, and
`disablesAnimations` directly; debug descriptions are not an equality contract.

Coverage includes boundaries, proxy routing, value triggers, simultaneous
changes, disabled updates, sequential updates, identity during trigger resizing,
stamp ownership, diagnostic controls, debounce, and RELEASE behavior. Pure tests
cover value comparison, selection, stamp identity, and bounded bookkeeping.

### Framework assumptions

Boundary stripping, local restoration, stamp propagation, and the value gate
must hold before features rely on them. Compatibility failures require a
reproduction and a design decision; do not silently change the public contract
to accommodate a changed OS behavior.

The hosted harness cannot establish `List` row propagation: row hooks may not
execute under unit hosting. Use the sample's row counters and visual checks.
Build success does not prove animation frames, cell reuse, or cancellation UI.
Run the [example QA procedure](Examples/QA.md) for supported OS and Xcode changes.

[Validation results](docs/validation.md) identify tested environments, actual
command output, and unverified areas.

## 9. Roadmap and dependency order

The roadmap has three ordered phases. Features may rely only on validated
foundation behavior.

| Phase | Scope | Status and gate |
| --- | --- | --- |
| 0 — SwiftUI assumptions | Stripping, local restoration, stamping, detector placement, value gating, and overlay geometry | Evidence and executable checks are documented in `docs/swiftui-assumptions.md`. Core behavior depends on these contracts. |
| 1 — Core library | Value and proxy scopes, barriers, DEBUG diagnostics, behavioral tests, DocC, CI, and sample QA | APIs are implemented. Release validation requires macOS and iOS tests, RELEASE auditing, documentation, and example QA. |
| 2 — Extensions | Multiple value triggers, transition helpers, lint guidance, and wider device validation | Multiple value triggers are implemented. Remaining candidates are listed below and require separate design decisions. |

Remaining candidates:

- Transition helpers with an explicit contract beyond the transaction support
  already provided by scopes.
- SwiftLint `custom_rules` guidance for teams restricting raw `withAnimation`
  and view animation modifiers. Rules must distinguish the supported
  `AnimationTrigger.animation(_:value:)` factory.
- Physical watchOS and visionOS validation.

No candidate changes the current scope ownership, boundary, or priority rules.
