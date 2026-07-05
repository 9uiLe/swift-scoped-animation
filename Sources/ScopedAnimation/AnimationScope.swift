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

  @ViewBuilder
  func body(content: Content) -> some View {
    let stampedContent = content.transaction { transaction in
      if let animation = transaction.animation {
        let currentStamp = transaction.animationScopeStamp
        if currentStamp == nil || currentStamp?.animation != animation {
          transaction.animationScopeStamp = stamp.withAnimation(animation)
        }
      }
    }

    if triggers.isEmpty {
      stampedContent
        .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
    } else if triggers.count == 1 {
      stampedContent
        .animation(triggers[0].animation, value: triggers[0].value)
        .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
    } else {
      stampedContent
        .modifier(
          MultiTriggerValueAnimationModifier(
            triggers: triggers,
            scopeName: scopeName
          )
        )
        .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
    }
  }
}

private struct MultiTriggerValueAnimationModifier: ViewModifier {
  let triggers: [AnimationTrigger]
  let scopeName: String?

  #if DEBUG
    @State private var warningSite = AnimationScopeRuntimeWarning.Site("MultiTriggerConflict")
  #endif

  @ViewBuilder
  func body(content: Content) -> some View {
    let animatedContent = triggers.reduce(AnyView(content)) { view, trigger in
      AnyView(view.animation(trigger.animation, value: trigger.value))
    }

    #if DEBUG
      animatedContent
        .onChange(of: TriggerValuesSnapshot(values: triggers.map(\.value))) {
          oldSnapshot,
          newSnapshot in
          let changedIndices = triggers.indices.filter {
            oldSnapshot.values[$0] != newSnapshot.values[$0]
          }

          if changedIndices.count > 1 {
            let adoptedIndex = changedIndices[0]
            let rejectedIndices = Array(changedIndices.dropFirst())
            AnimationScopeRuntimeWarning.report(
              .multiTriggerConflict(
                site: warningSite,
                scopeName: scopeName,
                adoptedTriggerIndex: adoptedIndex,
                adoptedAnimation: triggers[adoptedIndex].animation,
                rejectedTriggerIndices: rejectedIndices,
                rejectedAnimations: rejectedIndices.map { triggers[$0].animation }
              )
            )
          }
        }
    #else
      animatedContent
    #endif
  }
}

private struct TriggerValuesSnapshot: Equatable {
  let values: [AnyEquatable]
}

struct AnyEquatable: Equatable {
  private let value: Any
  private let equals: (Any) -> Bool

  init<Value: Equatable>(_ value: Value) {
    self.value = value
    self.equals = { other in
      guard let otherValue = other as? Value else {
        return false
      }
      return value == otherValue
    }
  }

  static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
    lhs.equals(rhs.value)
  }
}
