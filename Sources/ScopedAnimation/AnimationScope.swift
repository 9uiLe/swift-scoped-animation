import SwiftUI

/// A structural boundary for SwiftUI animation.
///
/// `AnimationScope` removes incoming animation and supplies animation from its
/// value triggers or a matching proxy stamp. Descendant SwiftUI modifiers can
/// still create their own animations; state updates are not contained by a scope.
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
    private let triggers: [AnimationTrigger]
    private let name: String?
    private let content: (AnimationScopeStamp) -> Content

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
        self.init(name: name, triggers: [.animation(animation, value: value)], content: content)
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
        self.triggers = []
        self.name = name
        self.content = { stamp in
            content(AnimationScopeProxy(animation: animation, stamp: stamp))
        }
    }

    /// The scoped content with its animation boundary and value triggers applied.
    public var body: some View {
        let namedStamp = stamp.named(name)

        content(namedStamp)
            .modifier(
                ValueAnimationResolverModifier(
                    triggers: triggers,
                    stamp: namedStamp
                )
            )
            .modifier(AnimationScopeBoundaryModifier(stamp: namedStamp))
            .animationScopeDebugBoundary(stamp: namedStamp)
    }
}
