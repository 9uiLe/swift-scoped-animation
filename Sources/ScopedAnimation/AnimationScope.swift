import SwiftUI

/// A structural boundary for SwiftUI animation.
///
/// `AnimationScope` blocks animations from ancestors, then allows only
/// animation created by the scope to affect its content.
///
/// ```swift
/// AnimationScope(.spring(duration: 0.3), value: isExpanded) {
///   CardContent(isExpanded: isExpanded)
/// }
/// ```
public struct AnimationScope<Content: View>: View {
  private let animation: Animation
  private let triggerValue: AnyEquatable?
  private let name: String?
  private let content: (AnimationScopeProxy) -> Content

  @State private var stamp = AnimationScopeStamp()

  /// Creates a value-driven animation scope.
  ///
  /// The subtree animates when `value` changes. Animations from ancestors are
  /// blocked at the scope boundary.
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
    self.triggerValue = AnyEquatable(value)
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
    self.triggerValue = nil
    self.name = name
    self.content = content
  }

  public var body: some View {
    let namedStamp = stamp.named(name)
    let proxy = AnimationScopeProxy(animation: animation, stamp: namedStamp)

    content(proxy)
      .modifier(
        AnimationScopeCoreModifier(
          animation: animation,
          triggerValue: triggerValue,
          stamp: namedStamp
        )
      )
  }
}

private struct AnimationScopeCoreModifier: ViewModifier {
  let animation: Animation
  let triggerValue: AnyEquatable?
  let stamp: AnimationScopeStamp

  @ViewBuilder
  func body(content: Content) -> some View {
    let stampedContent = content.transaction { transaction in
      if transaction.animation != nil, transaction.animationScopeStamp == nil {
        transaction.animationScopeStamp = stamp.withAnimation(transaction.animation)
      }
    }

    if let triggerValue {
      stampedContent
        .animation(animation, value: triggerValue)
        .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
    } else {
      stampedContent
        .modifier(AnimationScopeBoundaryModifier(stamp: stamp))
    }
  }
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
