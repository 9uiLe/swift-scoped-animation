# ScopedAnimation

日本語 | [English](README.en.md)

アニメーションを所有する領域を、SwiftUI のビュー構造で宣言するライブラリです。

<p align="center">
  <a href="https://github.com/9uiLe/swift-scoped-animation/actions/workflows/ci.yml"><img src="https://github.com/9uiLe/swift-scoped-animation/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://swiftpackageindex.com/9uiLe/swift-scoped-animation"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-scoped-animation%2Fbadge%3Ftype%3Dswift-versions" alt="対応 Swift バージョン"></a>
  <a href="https://swiftpackageindex.com/9uiLe/swift-scoped-animation"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-scoped-animation%2Fbadge%3Ftype%3Dplatforms" alt="対応プラットフォーム"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT ライセンス"></a>
</p>

<p align="center">
  <img src="docs/assets/overlay-hero.gif" alt="名前付きスコープの境界を表示する DEBUG オーバーレイ" width="640">
</p>

## 基本モデル

SwiftUI は、状態変更に伴うアニメーションを `Transaction` でビューへ伝えます。
ScopedAnimation は、その経路に境界を置きます。

- **スコープ**は外からのアニメーションを取り除き、値の変更や明示的な操作に応じて自身のアニメーションを与えます。
- **バリア**は外からのアニメーションを取り除きます。自身ではアニメーションを与えません。
- **スタンプ**はアニメーションの所有者を示す内部情報です。DEBUG 診断は、観測点を通るスタンプのないアニメーションを報告します。

状態を読むビューは、スコープの内外を問わず更新されます。プロキシによる明示的な操作のトランザクションも、
境界のない領域へ届きます。外からのアニメーションを拒否する領域には、スコープかバリアを配置してください。

## 導入

- iOS 17+、macOS 14+、tvOS 17+、watchOS 10+、visionOS 1+
- Swift 6 言語モード、Swift tools 6.2+
- Swift Package Manager、外部依存なし

Xcode に次のパッケージ URL を追加します。

```text
https://github.com/9uiLe/swift-scoped-animation.git
```

`Package.swift` では依存を宣言し、対象ターゲットに `ScopedAnimation` プロダクトを追加します。

```swift
.package(url: "https://github.com/9uiLe/swift-scoped-animation.git", from: "0.2.1")
```

## 値の変更でアニメーションさせる

`AnimationScope` で囲んだ内容が、監視する値の変更に応じて動きます。

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

初回表示では比較の基準を設定します。`isExpanded` が変わると、スコープが指定したアニメーションを内容へ渡します。
祖先のアニメーションは境界で取り除かれます。

### 同じ領域に複数の条件がある場合

値とアニメーションの組を、優先する順に並べます。

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

同時に複数の値が変わると、先頭に最も近い変更済みトリガーのアニメーションをサブツリー全体に使います。
DEBUG では不採用の変更も `multiTriggerConflict` として報告します。

比較は配列位置ごとに行い、具象型と値が両方等しければ変更なしとします。名前やアニメーション設定だけでは動きません。
要素数の変更は、内容の同一性とローカル状態を保ったまま、アニメーションなしで比較基準を設定し直します。
並べ替えは新しい位置での比較になります。意図した構成変更でなければ、要素数と順序を一定に保ってください。

## 明示的な操作でアニメーションさせる

内容のクロージャで受け取るプロキシの `animate` に、同期的な状態変更を渡します。

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

`scope.animate(.spring(duration: 0.4)) { ... }` は、その操作に使うアニメーションを指定します。
プロキシが付けたスタンプは祖先の境界を通過し、所有者の ID が一致するスコープでアニメーションを復元します。

## 境界を配置する

| 目的 | 構成 |
| --- | --- |
| 異なる表示レイヤーを独立して動かす | 兄弟スコープ |
| 同じサブツリーの複数条件に優先順位を付ける | 1 スコープの複数トリガー |
| 子孫に独立したアニメーションの所有者を置く | 入れ子のスコープ |
| 外からのアニメーションを取り除く | `animationBarrier()` |
| DEBUG に名前付き境界を表示し、値駆動アニメーションは与えない | `AnimationScope(name:triggers:content:)` に空配列 |

入れ子のスコープは祖先のアニメーションを取り除き、自身のトリガーやプロキシに応じて動きます。
DEBUG の `crossScopeAnimationStrip` は、このスコープ間の遮断を示します。

バリアは、次のように適用します。

```swift
StatusPanel()
    .animationBarrier()
```

スタンプは子孫のために保持します。スタンプのないアニメーションを除去したときの DEBUG 警告は、
`animationBarrier(warnsOnLeaks: false)` で抑制できます。空のトリガー配列によるスコープには、このバリア警告はありません。

バリアはレイアウト領域を確保しません。固定の大きさが必要なら通常のフレーム指定を併用します。
また、境界より下の SwiftUI アニメーション修飾子は独自のアニメーションを生成できます。

## DEBUG 診断

```swift
RootView()
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
```

検出器は、スタンプのないアニメーション付きトランザクションを報告します。オーバーレイはスコープの境界と名前を表示します。
診断実装は RELEASE ビルドから除去されます。

| 発生源 | ルートの検出器 | 発生源より下流の検出器・バリア |
| --- | --- | --- |
| スタンプのない `withAnimation` / アニメーション付き `withTransaction` | 通過時に検出 | 通過時に検出 |
| ルートより下の直接の `.animation(_:value:)` | 観測不可 | 通過時に検出 |
| スタンプ付きトランザクション | リーク報告なし | リーク報告なし |

観測できる範囲は配置に依存します。画面ルートと調査対象のサブツリーに検出器を置き、
直接のアニメーション呼び出しも確認してください。コード検索では SwiftUI の修飾子と
`AnimationTrigger.animation(_:value:)` ファクトリーを区別します。

## 性能と検証範囲

スコープは、動かすサブツリーを明示します。状態による無効化、`body` の評価回数、フレームレートは制御しません。
トリガーの生成と等価比較にはコストがあるため、条件を十分に表す小さな値を使ってください。
[性能ガイド](Sources/ScopedAnimation/Documentation.docc/PerformancePlaybook.md)はアプリの計測を、
[参考計測](docs/performance.md)は内部の CPU コストを扱います。

トランザクション伝播は macOS / iOS のホストテストで検証します。
`List` 行への伝播、再利用、実際の描画は[サンプル QA](Examples/QA.md)で環境ごとに確認します。
OS や Xcode のメジャー更新時は、[互換性の前提](docs/swiftui-assumptions.md)を再検証してください。

## サンプル

比較、オーバーレイ、リスト検証、複数トリガーを操作できます。サンプル UI は日本語です。
掲載 GIF は英語 UI で収録した動作例です。

<p align="center">
  <img src="docs/assets/compare-demo.gif" alt="直接のアニメーションとスコープの比較" width="310">
  <img src="docs/assets/list-qa-demo.gif" alt="List の伝播とバリアの動作確認" width="310">
</p>

```sh
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 文書の案内

日本語を基本言語とし、README・貢献ガイド・セキュリティ方針・行動規範に英語版を提供します。
文書の責務と同期方法は[貢献ガイドの言語方針](CONTRIBUTING.md#言語方針)に定義しています。

| 読みたいこと | 文書 |
| --- | --- |
| API の使い方 | [使い始める](Sources/ScopedAnimation/Documentation.docc/GettingStarted.md)・[組み合わせ方](Sources/ScopedAnimation/Documentation.docc/Composition.md) |
| トランザクションが届く仕組み | [仕組み](Sources/ScopedAnimation/Documentation.docc/HowItWorks.md) |
| 製品契約・内部構造・ロードマップ | [設計](HANDOFF.md) |
| 開発環境・テスト・文書の管理 | [貢献ガイド](CONTRIBUTING.md) |
| バージョンの準備と公開 | [リリース手順](docs/releasing.md) |
| 実行環境・実出力・検証の限界 | [検証記録](docs/validation.md) |
| 報告と参加のルール | [セキュリティ方針](SECURITY.md)・[行動規範](CODE_OF_CONDUCT.md) |

DocC は Xcode でビルドします。

```sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS'
```

## ライセンス

[MIT](LICENSE)
