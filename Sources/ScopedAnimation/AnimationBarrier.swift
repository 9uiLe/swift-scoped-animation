import SwiftUI

extension View {
    /// スコープのスタンプを保持し、外から届くアニメーションを取り除きます。
    ///
    /// 親のアニメーションを受けたくない既存 UI や静的な領域にバリアを配置します。
    /// 子孫の `AnimationScope` は、自身の値駆動アニメーションを与えたり、
    /// ID の一致するプロキシスタンプからアニメーションを復元したりできます。
    ///
    /// ```swift
    /// LegacyDashboard()
    ///   .animationBarrier()
    /// ```
    /// - Parameter warnsOnLeaks: `false` を渡すと DEBUG 専用のリーク警告を抑制します。
    public func animationBarrier(warnsOnLeaks: Bool = true) -> some View {
        modifier(AnimationScopeBoundaryModifier(warnsOnLeaks: warnsOnLeaks))
    }
}
