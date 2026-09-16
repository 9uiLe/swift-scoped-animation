import SwiftUI

/// SwiftUI アニメーションの所有者をビューの境界で宣言するコンテナです。
///
/// `AnimationScope` は外からのアニメーションを取り除き、値トリガーまたは
/// 一致するプロキシスタンプからアニメーションを与えます。子孫の SwiftUI 修飾子は
/// 独自のアニメーションを生成でき、状態更新もスコープ内には限定されません。
///
/// 入れ子のスコープは、同じサブツリーのアニメーションを合成しません。
/// 子孫は祖先のスタンプ付きアニメーションを取り除き、自身のスタンプだけを復元します。
/// DEBUG では、この遮断を `crossScopeAnimationStrip` として報告します。
///
/// ```swift
/// AnimationScope(.spring(duration: 0.3), value: isExpanded) {
///   CardContent(isExpanded: isExpanded)
/// }
/// ```
public struct AnimationScope<Content: View>: View {
    private let triggers: [AnimationTrigger]
    private let name: String?
    private let content: (AnimationScopeStamp) -> Content

    @State private var stamp = AnimationScopeStamp()

    /// 値の変更を起点にアニメーションするスコープを作ります。
    ///
    /// `value` が変わるとサブツリーをアニメーションさせます。
    /// 祖先の `AnimationScope` も含め、外からのアニメーションは境界で遮断します。
    ///
    /// ```swift
    /// AnimationScope(.smooth, value: isSelected) {
    ///   SelectionIndicator(isSelected: isSelected)
    /// }
    /// ```
    public init<Value: Equatable>(
        _ animation: Animation,
        value: Value,
        name: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(name: name, triggers: [.animation(animation, value: value)], content: content)
    }

    /// 複数の値トリガーを持つスコープを作ります。
    ///
    /// 宣言した値のいずれかが変わると、サブツリーをアニメーションさせます。
    /// 同じトランザクションで複数の値が変わった場合は、`triggers` の先頭に
    /// 最も近い変更済みトリガーを採用します。
    ///
    /// 配列の構成と順序は一定に保ってください。要素数の変更は構造更新として扱い、
    /// アニメーションしません。並べ替えると新しい位置で比較し、その位置が優先順位になります。
    /// 空配列は外からのアニメーションを除去する名前付き境界を作ります。
    /// 境界の診断ラベルが不要なら ``animationBarrier(warnsOnLeaks:)`` を使ってください。
    ///
    /// ```swift
    /// AnimationScope(
    ///   name: "Board",
    ///   triggers: [
    ///     .animation(.easeOut(duration: 0.12), value: selectedPoints),
    ///     .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints),
    ///   ]
    /// ) {
    ///   BoardView()
    /// }
    /// ```
    public init(
        name: String? = nil,
        triggers: [AnimationTrigger],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.triggers = triggers
        self.name = name
        self.content = { _ in content() }
    }

    /// プロキシの明示的な操作でアニメーションするスコープを作ります。
    ///
    /// プロキシ経由で実行した状態変更にだけ、スコープのアニメーションを与えます。
    ///
    /// ```swift
    /// AnimationScope(.snappy) { scope in
    ///   CardContent()
    ///     .onTapGesture {
    ///       scope.animate { isExpanded.toggle() }
    ///     }
    /// }
    /// ```
    public init(
        _ animation: Animation,
        name: String? = nil,
        @ViewBuilder content: @escaping (AnimationScopeProxy) -> Content
    ) {
        self.triggers = []
        self.name = name
        self.content = { stamp in
            content(AnimationScopeProxy(animation: animation, stamp: stamp))
        }
    }

    /// アニメーション境界と値トリガーを適用した内容です。
    public var body: some View {
        let namedStamp = stamp.named(name)

        content(namedStamp)
            .modifier(
                ValueAnimationResolverModifier(
                    triggers: triggers,
                    stamp: namedStamp
                )
            )
            .modifier(AnimationScopeBoundaryModifier(stamp: namedStamp))
            .animationScopeDebugBoundary(stamp: namedStamp)
    }
}
