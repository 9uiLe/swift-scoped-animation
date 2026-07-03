import SwiftUI

extension View {
  /// Reports unscoped animation transactions that pass through this view in debug builds.
  ///
  /// Install the detector near a screen root, or around a suspicious subtree when tracking
  /// an animation leak.
  ///
  /// ```swift
  /// RootView()
  ///   .detectAnimationLeaks()
  /// ```
  public func detectAnimationLeaks() -> some View {
    modifier(AnimationLeakDetectorModifier())
  }
}

#if DEBUG
  private struct AnimationLeakDetectorModifier: ViewModifier {
    @State private var warningSite = AnimationScopeRuntimeWarning.Site("detectAnimationLeaks")

    func body(content: Content) -> some View {
      content.transaction { transaction in
        if transaction.animation != nil, transaction.animationScopeStamp == nil {
          AnimationScopeRuntimeWarning.report(
            .unscopedAnimation(site: warningSite)
          )
        }
      }
    }
  }
#else
  private struct AnimationLeakDetectorModifier: ViewModifier {
    func body(content: Content) -> some View {
      content
    }
  }
#endif
