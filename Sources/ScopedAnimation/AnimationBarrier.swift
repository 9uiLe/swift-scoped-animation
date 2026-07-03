import SwiftUI

extension View {
  /// Prevents incoming animation transactions from reaching a subtree.
  ///
  /// Use a barrier around legacy or intentionally static UI when parent animations should
  /// not affect it.
  ///
  /// ```swift
  /// LegacyDashboard()
  ///   .animationBarrier()
  /// ```
  public func animationBarrier() -> some View {
    modifier(AnimationBarrierModifier())
  }
}

struct AnimationBarrierModifier: ViewModifier {
  func body(content: Content) -> some View {
    content.transaction { transaction in
      transaction.animation = nil
    }
  }
}

struct AnimationScopeBoundaryModifier: ViewModifier {
  let stamp: AnimationScopeStamp

  func body(content: Content) -> some View {
    content.transaction { transaction in
      let incomingStamp = transaction.animationScopeStamp
      transaction.animation = nil

      guard !transaction.disablesAnimations,
        incomingStamp?.id == stamp.id,
        let restoredAnimation = incomingStamp?.animation
      else {
        return
      }

      transaction.animation = restoredAnimation
    }
  }
}
