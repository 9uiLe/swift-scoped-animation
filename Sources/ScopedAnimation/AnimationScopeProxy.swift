import SwiftUI

/// A trigger object that runs state changes with a scope-owned animation.
///
/// Use the proxy when an interaction should animate only the subtree inside its
/// `AnimationScope`.
///
/// ```swift
/// AnimationScope(.snappy) { scope in
///     Button("Toggle") {
///         scope.animate {
///             isExpanded.toggle()
///         }
///     }
/// }
/// ```
public struct AnimationScopeProxy {
  private let animation: Animation
  private let stamp: AnimationScopeStamp

  init(animation: Animation, stamp: AnimationScopeStamp) {
    self.animation = animation
    self.stamp = stamp
  }

  /// Runs `body` with the scope's default animation.
  ///
  /// ```swift
  /// scope.animate {
  ///     isExpanded.toggle()
  /// }
  /// ```
  public func animate(_ body: () -> Void) {
    animate(animation, body)
  }

  /// Runs `body` with a one-off animation for this trigger.
  ///
  /// ```swift
  /// scope.animate(.spring(duration: 0.4)) {
  ///     selection = nextSelection
  /// }
  /// ```
  public func animate(_ animation: Animation, _ body: () -> Void) {
    var transaction = Transaction(animation: animation)
    transaction.animationScopeStamp = stamp.withAnimation(animation)
    withTransaction(transaction, body)
  }
}
