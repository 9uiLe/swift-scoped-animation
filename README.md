# ScopedAnimation

日本語 | [English](README.en.md)

SwiftUI アニメーションの境界を宣言し、DEBUG 診断で意図しない伝播を見つけるライブラリです。

<p align="center">
  <a href="https://github.com/9uiLe/swift-scoped-animation/actions/workflows/ci.yml"><img src="https://github.com/9uiLe/swift-scoped-animation/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://swiftpackageindex.com/9uiLe/swift-scoped-animation"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-scoped-animation%2Fbadge%3Ftype%3Dswift-versions" alt="対応 Swift バージョン"></a>
  <a href="https://swiftpackageindex.com/9uiLe/swift-scoped-animation"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-scoped-animation%2Fbadge%3Ftype%3Dplatforms" alt="対応プラットフォーム"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT ライセンス"></a>
</p>

<p align="center">
  <img src="docs/assets/overlay-hero.gif" alt="名前付きスコープの境界を表示する DEBUG オーバーレイ" width="640">
</p>

<p align="center">
  <img src="docs/assets/compare-demo.gif" alt="スコープ導入前後の比較" width="310">
  <img src="docs/assets/list-qa-demo.gif" alt="List の伝播とバリアの動作確認" width="310">
</p>

ScopedAnimation は、アニメーションの所有者をビューの構造で表します。
スコープとバリアは外から届くアニメーションを取り除き、スコープが与えるアニメーションには
所有者を示すスタンプを付けます。DEBUG 診断は、観測点を通るスタンプのないトランザクションを報告します。

状態の変更は、その状態を読むすべてのビューに届きます。プロキシのトランザクションは、
境界を宣言していないビューもアニメーションさせることがあります。
外からのアニメーションを受け取りたくない領域には、スコープかバリアを配置してください。

## 動作要件と導入

- iOS 17+、macOS 14+、tvOS 17+、watchOS 10+、visionOS 1+
- Swift 6 言語モード。パッケージ定義には Swift tools 6.2+ が必要
- Swift Package Manager のみ。外部依存なし

Xcode で次の URL を追加します。

```text
https://github.com/9uiLe/swift-scoped-animation.git
```

またはパッケージを宣言し、ターゲットの依存に `ScopedAnimation` を追加します。

```swift
.package(url: "https://github.com/9uiLe/swift-scoped-animation.git", from: "0.2.1")
```

## アニメーションの所有者を選ぶ

| 用途 | API |
| --- | --- |
| 1 つの値が変わったらサブツリーをアニメーションさせる | `AnimationScope(_:value:name:content:)` |
| 同じサブツリーの複数の値からアニメーションを選ぶ | `AnimationScope(name:triggers:content:)` |
| 明示的な操作に含まれる状態変更をアニメーションさせる | プロキシを受け取る `AnimationScope(_:name:content:)` |
| 自分ではアニメーションを与えず、外からのアニメーションを取り除く | `animationBarrier(warnsOnLeaks:)` |

### 1 つの値を監視する

```swift
import ScopedAnimation
import SwiftUI

AnimationScope(.spring(duration: 0.3), value: isExpanded, name: "Card") {
    CardContent(isExpanded: isExpanded)
}
```

境界が祖先のアニメーションを取り除きます。`isExpanded` が変わると、スコープのアニメーションが内容に適用されます。

### 複数の値を監視する

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

複数の値が同時に変わると、配列の先頭に最も近い変更済みトリガーを採用します。
DEBUG ビルドでは、採用しなかった変更済みトリガーも報告します。

値は具象型と等価性の両方で比較します。アニメーションの設定だけを変えても動きません。
配列の要素数を変えると、アニメーションを開始せず比較の基準を設定し直します。
並べ替えた場合は、新しい位置で値を比較します。意図した変更でなければ、要素数と順序を一定に保ってください。
要素数が変わっても、内容のビューの同一性とローカル状態は維持されます。

### 明示的な操作をアニメーションさせる

```swift
AnimationScope(.snappy, name: "Disclosure") { scope in
    Button("切り替え") {
        scope.animate {
            isOpen.toggle()
        }
    }
}
```

`scope.animate(.spring(duration: 0.4)) { ... }` で、1 回の同期的な操作に使うアニメーションを指定できます。
プロキシはトランザクションにスタンプを付けます。祖先のスコープやバリアがアニメーションを取り除いても、
ID が一致する境界で復元できます。

### バリアで遮断する

```swift
LegacyDashboard()
    .animationBarrier()
```

バリアは外から届くアニメーションを取り除き、子孫のスコープのためにスタンプを保持します。
既存コードのアニメーションを意図的に遮断する場合は、`warnsOnLeaks: false` で DEBUG 警告を抑制できます。

バリアはレイアウト領域を確保せず、子孫の SwiftUI 修飾子が独自のアニメーションを生成することも妨げません。
領域の大きさも固定したい場合は、固定フレームなど通常のレイアウトを併用します。

## スコープを組み合わせる

別々の表示レイヤーには兄弟スコープを使います。同じサブツリーを複数の値が制御する場合は、
1 つのスコープに複数のトリガーを宣言します。

入れ子のスコープは、それぞれ独立した境界です。祖先のアニメーションを取り除き、
自身の値が変わったとき、または自身のプロキシスタンプと一致したときにアニメーションを与えます。
DEBUG の `crossScopeAnimationStrip` はスコープ間の遮断を、`multiTriggerConflict` は同じスコープ内の競合を示します。

空のトリガー配列は、DEBUG オーバーレイに表示される名前付き境界になります。
名前が不要なら `animationBarrier()` を使ってください。

## 所有者と境界を確認する

```swift
RootView()
    .detectAnimationLeaks()
    .animationScopeDebugOverlay()
```

検出器は、スコープのスタンプがないアニメーション付きトランザクションを報告します。
オーバーレイは、名前付きスコープの境界を描画します。どちらの診断実装も RELEASE ビルドから除去されます。

| 発生源 | ルートの検出器 | 発生源より下流の検出器またはバリア |
| --- | --- | --- |
| 直接の `withAnimation`、またはスタンプのないアニメーション付き `withTransaction` | 通過するトランザクションを検出 | 通過するトランザクションを検出 |
| ルート検出器より下にある直接の `.animation(_:value:)` | 下で生成されたアニメーションは観測不可 | 通過するトランザクションを検出 |
| スタンプ付きトランザクション | リークを報告しない | リークを報告しない |

まず画面のルートに検出器を置き、調査対象のサブツリーにも必要に応じて追加します。
外からのアニメーションを拒否する領域にはバリアを置きます。観測できる範囲は配置に依存するため、
直接のアニメーション呼び出しもレビューしてください。静的チェックでは、SwiftUI のビュー修飾子と、
サポートされる `AnimationTrigger.animation` ファクトリーを区別する必要があります。

## 性能と互換性

スコープを小さくすると、動かすサブツリーを明確にできます。
状態によるビューの無効化を防いだり、`body` の評価回数を減らしたりする保証はありません。

トリガーの生成・等価比較・DEBUG 診断にはコストがあります。
条件を十分に表現できる範囲で、小さな値を使ってください。
[性能ガイド](Sources/ScopedAnimation/Documentation.docc/PerformancePlaybook.md)ではアプリの計測方法を、
[参考計測](docs/performance.md)では内部の CPU コストと計測の限界を説明しています。

トランザクション伝播は、SwiftUI 上で観測された挙動に依存します。
自動テストは macOS と iOS のホスティング環境で検証しています。
`List` 行への伝播やセルの再利用には、[サンプルの QA 手順](Examples/QA.md)による環境ごとの確認が必要です。
Xcode や OS のメジャーバージョンを更新するときは、互換性を再確認してください。

## サンプルアプリ

比較・オーバーレイ・リスト検証・複数トリガーの画面を収録しています。
上のデモ画像は、収録時の英語 UI を表示しています。

```sh
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## ドキュメント

- [使い始める](Sources/ScopedAnimation/Documentation.docc/GettingStarted.md)：実行可能な使用例
- [組み合わせ方](Sources/ScopedAnimation/Documentation.docc/Composition.md)：兄弟・入れ子のスコープと固定レイアウト
- [仕組み](Sources/ScopedAnimation/Documentation.docc/HowItWorks.md)：トランザクション・スタンプ・値の解決・診断の配置
- [設計](HANDOFF.md)：製品の契約・内部構造・ロードマップ
- [貢献ガイド](CONTRIBUTING.md)：リポジトリ構成と必要な検証
- [リリース手順](docs/releasing.md)：所有者向けコマンド・コミット検証・公開の再開
- [検証記録](docs/validation.md)：実行環境・出力・未検証の範囲
- [セキュリティ方針](SECURITY.md)・[行動規範](CODE_OF_CONDUCT.md)

日本語を基本言語とし、README・貢献ガイド・セキュリティ方針・行動規範には英語版も用意しています。
言語ごとの管理方針は[貢献ガイド](CONTRIBUTING.md#言語方針)を参照してください。

Xcode で DocC をビルドできます。

```sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS'
```

`swift-docc-plugin` は不要です。

## ライセンス

MIT。[LICENSE](LICENSE) を参照してください。
