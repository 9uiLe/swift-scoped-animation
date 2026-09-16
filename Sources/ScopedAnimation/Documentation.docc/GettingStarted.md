# 使い始める

アニメーションの所有者を宣言し、その境界を確認します。

## 値の変更をアニメーションさせる

値によって内容を動かすかどうかが決まる場合は、値駆動スコープを使います。

```swift
import ScopedAnimation
import SwiftUI

struct ExpandableCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Button("詳細を切り替え") {
                isExpanded.toggle()
            }

            AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
                VStack(alignment: .leading) {
                    Text("売上")
                    if isExpanded {
                        Text("月次の詳細")
                            .transition(.opacity)
                    }
                }
            }
        }
    }
}
```

スコープは祖先からのアニメーションを取り除きます。
`isExpanded` が変わると、内容の更新にスコープのアニメーションを与えます。

## 複数の値から選ぶ

1 つのサブツリーに複数のアニメーション条件がある場合は、複数トリガーを使います。

```swift
AnimationScope(
    name: "Board",
    triggers: [
        .animation(.easeOut(duration: 0.12), value: selectedPoints),
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hintPoints),
    ]
) {
    BoardView()
}
```

同時に値が変わると、先頭に最も近い変更済みトリガーを採用します。DEBUG 診断は不採用の変更も報告します。
要素数と順序は一定に保ってください。動的に変更する場合の挙動は <doc:HowItWorks> を参照してください。

## 明示的な操作をアニメーションさせる

操作によって動かす状態変更を決める場合は、プロキシを使います。

```swift
AnimationScope(.snappy, name: "Disclosure") { scope in
    VStack {
        Button("切り替え") {
            scope.animate {
                isOpen.toggle()
            }
        }
        DisclosureContent(isOpen: isOpen)
    }
}
```

1 回の同期操作だけ、既定のアニメーションを上書きできます。

```swift
scope.animate(.spring(duration: 0.45)) {
    selection = nextSelection
}
```

プロキシはトランザクションにスタンプを付けます。変更した状態を読む他のビューにも届くため、
その領域でアニメーションを拒否するには、別のスコープかバリアが必要です。

## 外からのアニメーションを遮断する

```swift
LegacyDashboard()
    .animationBarrier()
```

バリアは外からのアニメーションを取り除き、子孫のためにスタンプを保持します。
DEBUG ではスタンプのない入力も報告します。既存コードを意図的に遮断する場合は、
`animationBarrier(warnsOnLeaks: false)` で警告を抑制できます。

## 画面を確認する

```swift
RootView()
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
```

検出器は、その点を通過するスタンプなしアニメーションを報告します。
オーバーレイはスコープの境界と名前を表示します。どちらも RELEASE から診断実装が除去されます。

ルートの検出器には、下で生成された直接の値アニメーションは見えません。その場合は発生源の下流に配置します。
所有者の配置は <doc:Composition>、コストと計測方法は <doc:PerformancePlaybook> を参照してください。
