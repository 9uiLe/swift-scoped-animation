# ScopedAnimation

SwiftUI アニメーションの所有者と境界をビューの構造で宣言します。

## Overview

SwiftUI は、状態変更に伴うアニメーションをトランザクションでビューへ伝えます。
ScopedAnimation の境界は外からのアニメーションを取り除き、スコープは自身が所有するアニメーションを与えます。
所有者を示す内部情報をスタンプと呼びます。DEBUG 診断はスタンプのないアニメーションを検出し、スコープの境界を表示します。

```swift
AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
    CardContent(isExpanded: isExpanded)
}
```

この例は `isExpanded` の変更で内容をアニメーションさせます。
複数の条件にはトリガー配列、明示的な同期操作にはプロキシ、外からのアニメーションの除去にはバリアを使います。

状態を読むすべてのビューは更新対象です。プロキシのトランザクションは境界のない領域にも届き、
下流の SwiftUI 修飾子は独自のアニメーションを生成できます。遮断と検出の範囲は、境界や観測点の配置によって決まります。

<doc:GettingStarted> で基本の使い方、<doc:Composition> で領域に合わせた配置を説明します。
トランザクションの処理は <doc:HowItWorks>、コストと計測は <doc:PerformancePlaybook> を参照してください。

## Topics

### ガイド

- <doc:GettingStarted>
- <doc:Composition>
- <doc:HowItWorks>
- <doc:PerformancePlaybook>

### スコープ API

- ``AnimationScope``
- ``AnimationTrigger``
- ``AnimationScopeProxy``
