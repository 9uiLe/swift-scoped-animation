# ScopedAnimation

SwiftUI アニメーションの境界をビューの構造で宣言します。

## Overview

ScopedAnimation は、次の 3 つの操作でアニメーションの所有者を明確にします。

- 境界が外からのアニメーションを取り除く。
- スコープが所有者を示すスタンプ付きのアニメーションを与える。
- DEBUG ツールがスタンプのないトランザクションを報告し、境界を表示する。

値の変更でサブツリーを動かす場合は、値駆動スコープを使います。

```swift
AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
    CardContent(isExpanded: isExpanded)
}
```

複数の値が同じサブツリーを制御する場合は複数トリガーを、明示的な操作で対象の状態変更を決める場合はプロキシを使います。

状態変更は、その状態を読むすべてのビューに届きます。プロキシのトランザクションは宣言した境界の外へも届き、
直接のアニメーション修飾子は検出器より下でアニメーションを作れます。
スコープとバリアが提供するのは、宣言した場所での遮断と検出です。

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
