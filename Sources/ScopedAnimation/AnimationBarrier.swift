import SwiftUI

/// A view modifier that prevents incoming animation transactions from reaching a subtree.
///
/// Use a barrier around legacy or intentionally static UI when parent animations should
/// not affect it.
///
/// ```swift
/// LegacyDashboard()
///     .animationBarrier()
/// ```
extension View {
  public func animationBarrier() -> some View {
    modifier(AnimationBarrierModifier())
  }
}

struct AnimationBarrierModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.transaction { transaction in
      transaction.animation = nil
      transaction.animationScopeStamp = nil
    }
  }
}

struct AnimationScopeBoundaryModifier: ViewModifier {
  let stamp: AnimationScopeStamp

  func body(content: Content) -> some View {
    content.transaction { transaction in
      guard let transactionStamp = transaction.animationScopeStamp,
        transactionStamp.isAllowed(through: stamp)
      else {
        transaction.animation = nil
        transaction.animationScopeStamp = nil
        return
      }
    }
  }
}
