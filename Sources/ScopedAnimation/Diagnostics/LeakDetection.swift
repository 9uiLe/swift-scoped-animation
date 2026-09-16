import SwiftUI

extension View {
    /// このビューを通るスコープ未指定のアニメーションを DEBUG ビルドで報告します。
    ///
    /// 画面ルート付近に配置します。リークを調べる場合は、疑わしいサブツリーにも配置してください。
    ///
    /// ```swift
    /// RootView()
    ///   .detectAnimationLeaks()
    /// ```
    public func detectAnimationLeaks() -> some View {
        #if DEBUG
            modifier(AnimationLeakDetectorModifier())
        #else
            self
        #endif
    }
}

#if DEBUG
    private struct AnimationLeakDetectorModifier: ViewModifier {
        func body(content: Content) -> some View {
            content.transaction { transaction in
                if transaction.animation != nil, transaction.animationScopeStamp == nil {
                    AnimationScopeRuntimeWarning.report(
                        .unscopedAnimation
                    )
                }
            }
        }
    }
#endif
