import SwiftUI

/// A structural boundary for SwiftUI animation.
///
/// `AnimationScope` blocks animations from ancestors, then allows only
/// animation created by the scope to affect its content.
///
/// Nested scopes do not combine animations for the same subtree. A descendant
/// scope strips an ancestor scope's stamped animation and restores only its own
/// stamp. In DEBUG builds, that cross-scope strip is reported as
/// `crossScopeAnimationStrip`.
///
/// ```swift
/// AnimationScope(.spring(duration: 0.3), value: isExpanded) {
///   CardContent(isExpanded: isExpanded)
/// }
/// ```
public struct AnimationScope<Content: View>: View {
  private let animation: Animation
  private let triggers: [AnimationTrigger]
  private let name: String?
  private let content: (AnimationScopeProxy) -> Content

  @State private var stamp = AnimationScopeStamp()

  /// Creates a value-driven animation scope.
  ///
  /// The subtree animates when `value` changes. Animations from ancestors are
  /// blocked at the scope boundary, including animations created by an ancestor
  /// `AnimationScope`.
  ///
  /// ```swift
  /// AnimationScope(.smooth, value: isSelected) {
  ///   SelectionIndicator(isSelected: isSelected)
  /// }
  /// ```
  public init<Value: Equatable>(
    _ animation: Animation,
    value: Value,
    name: String? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.animation = animation
    self.triggers = [.animation(animation, value: value)]
    self.name = name
    self.content = { _ in content() }
  }

  /// Creates a multi-trigger value-driven animation scope.
  ///
  /// The subtree animates when any configured trigger value changes. When
  /// multiple trigger values change in the same transaction, the trigger
  /// closest to the start of the `triggers` array wins.
  ///
  /// Keep the array's composition and order stable. Changing its count is a
  /// structural update and does not animate. Reordering compares values by
  /// their new positions, and those positions also define conflict priority.
  /// An empty array creates a named boundary that strips incoming animations
  /// without restoring one; prefer ``animationBarrier(warnsOnLeaks:)``
  /// when a diagnostic boundary label is unnecessary.
  ///
  /// ```swift
  /// AnimationScope(
  ///   name: "Board",
  ///   triggers: [
  ///     .animation(.easeOut(duration: 0.12), value: selectedPoints),
  ///     .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints),
  ///   ]
  /// ) {
  ///   BoardView()
  /// }
  /// ```
  public init(
    name: String? = nil,
    triggers: [AnimationTrigger],
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.animation = triggers.first?.animation ?? .default
    self.triggers = triggers
    self.name = name
    self.content = { _ in content() }
  }

  /// Creates a proxy-driven animation scope.
  ///
  /// Only state changes performed through the proxy receive the scope's animation.
  ///
  /// ```swift
  /// AnimationScope(.snappy) { scope in
  ///   CardContent()
  ///     .onTapGesture {
  ///       scope.animate { isExpanded.toggle() }
  ///     }
  /// }
  /// ```
  public init(
    _ animation: Animation,
    name: String? = nil,
    @ViewBuilder content: @escaping (AnimationScopeProxy) -> Content
  ) {
    self.animation = animation
    self.triggers = []
    self.name = name
    self.content = content
  }

  public var body: some View {
    let namedStamp = stamp.named(name)
    let proxy = AnimationScopeProxy(animation: animation, stamp: namedStamp)

    content(proxy)
      .modifier(
        AnimationScopeCoreModifier(
          triggers: triggers,
          scopeName: name,
          stamp: namedStamp
        )
      )
      .animationScopeDebugBoundary(stamp: namedStamp)
  }
}

private struct AnimationScopeCoreModifier: ViewModifier {
  let triggers: [AnimationTrigger]
  let scopeName: String?
  let stamp: AnimationScopeStamp

  func body(content: Content) -> some View {
    content
      .modifier(
        ValueAnimationResolverModifier(
          triggers: triggers,
          scopeName: scopeName,
          stamp: stamp
        )
      )
      .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
  }
}

private struct ValueAnimationResolverModifier: ViewModifier {
  let triggers: [AnimationTrigger]
  let scopeName: String?
  let stamp: AnimationScopeStamp

  @State private var history: AnimationTriggerHistory

  init(
    triggers: [AnimationTrigger],
    scopeName: String?,
    stamp: AnimationScopeStamp
  ) {
    self.triggers = triggers
    self.scopeName = scopeName
    self.stamp = stamp
    _history = State(
      initialValue: AnimationTriggerHistory(
        initialSnapshot: AnimationTriggerSnapshot(triggers: triggers)
      )
    )
  }

  func body(content: Content) -> some View {
    let snapshot = AnimationTriggerSnapshot(triggers: triggers)
    let resolution = history.resolve(current: snapshot, triggers: triggers)

    content.transaction(value: snapshot) { transaction in
      guard !transaction.disablesAnimations, let resolution else {
        return
      }

      transaction.animation = resolution.adoptedAnimation
      transaction.animationScopeStamp = stamp.withAnimation(resolution.adoptedAnimation)

      #if DEBUG
        if !resolution.rejectedTriggerIndices.isEmpty {
          AnimationScopeRuntimeWarning.report(
            .multiTriggerConflict(
              site: AnimationScopeRuntimeWarning.Site(
                "MultiTriggerConflict",
                scopeName: scopeName
              ),
              scopeName: scopeName,
              adoptedTriggerIndex: resolution.adoptedTriggerIndex,
              adoptedAnimation: resolution.adoptedAnimation,
              rejectedTriggerIndices: resolution.rejectedTriggerIndices,
              rejectedAnimations: resolution.rejectedAnimations
            )
          )
        }
      #endif
    }
  }
}
