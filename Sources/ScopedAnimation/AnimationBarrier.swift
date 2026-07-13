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
  /// - Parameter warnsOnLeaks: Pass `false` to silence the debug-only leak warning.
  public func animationBarrier(warnsOnLeaks: Bool = true) -> some View {
    modifier(AnimationBarrierModifier(warnsOnLeaks: warnsOnLeaks))
  }
}

struct AnimationBarrierModifier: ViewModifier {
  #if DEBUG
    let warnsOnLeaks: Bool

    init(warnsOnLeaks: Bool) {
      self.warnsOnLeaks = warnsOnLeaks
    }
  #else
    init(warnsOnLeaks: Bool) {}
  #endif

  func body(content: Content) -> some View {
    content.transaction { transaction in
      #if DEBUG
        if warnsOnLeaks, transaction.animation != nil, transaction.animationScopeStamp == nil {
          AnimationScopeRuntimeWarning.report(
            .barrierLeak(site: AnimationScopeRuntimeWarning.Site("animationBarrier"))
          )
        }
      #endif

      transaction.animation = nil
    }
  }
}
