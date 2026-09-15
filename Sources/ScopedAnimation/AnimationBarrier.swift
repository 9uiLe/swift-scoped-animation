import SwiftUI

extension View {
    /// Strips incoming animation while preserving scoped transaction stamps.
    ///
    /// Use a barrier around legacy or intentionally static UI when parent animations should
    /// not affect it. A descendant `AnimationScope` can still supply its own value-driven
    /// animation or restore its matching proxy stamp.
    ///
    /// ```swift
    /// LegacyDashboard()
    ///   .animationBarrier()
    /// ```
    /// - Parameter warnsOnLeaks: Pass `false` to silence the debug-only leak warning.
    public func animationBarrier(warnsOnLeaks: Bool = true) -> some View {
        modifier(AnimationScopeBoundaryModifier(warnsOnLeaks: warnsOnLeaks))
    }
}
