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
    @State private var warningSite = AnimationScopeRuntimeWarning.Site("animationBarrier")

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
            .barrierLeak(site: warningSite)
          )
        }
      #endif

      transaction.animation = nil
    }
  }
}

struct AnimationScopeBoundaryModifier: ViewModifier {
  let stamp: AnimationScopeStamp
  #if DEBUG
    @State private var warningSite = AnimationScopeRuntimeWarning.Site("AnimationScopeBoundary")
  #endif

  func body(content: Content) -> some View {
    content.transaction { transaction in
      #if DEBUG
        let incomingAnimation = transaction.animation
      #endif
      let incomingStamp = transaction.animationScopeStamp

      #if DEBUG
        if !transaction.disablesAnimations,
          incomingAnimation != nil,
          let incomingStamp,
          incomingStamp.id != stamp.id,
          incomingStamp.animation != nil
        {
          AnimationScopeRuntimeWarning.report(
            .crossScopeAnimationStrip(
              site: warningSite,
              strippingScopeName: stamp.name,
              strippedScopeName: incomingStamp.name
            )
          )
        }
      #endif

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
