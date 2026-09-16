import SwiftUI

/// スコープが所有するアニメーションで状態変更を実行するプロキシです。
///
/// 操作によって `AnimationScope` 内のサブツリーを動かす場合に使います。
/// 他の領域でこのアニメーションを遮断するには、別のスコープかバリアを宣言してください。
/// 状態変更は、その状態を読むすべてのビューに届きます。
///
/// ```swift
/// AnimationScope(.snappy) { scope in
///     Button("切り替え") {
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

    /// スコープの既定のアニメーションで `body` を実行します。
    ///
    /// ```swift
    /// scope.animate {
    ///     isExpanded.toggle()
    /// }
    /// ```
    public func animate(_ body: () -> Void) {
        animate(animation, body)
    }

    /// この呼び出しで指定したアニメーションで `body` を実行します。
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
