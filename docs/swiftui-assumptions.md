# SwiftUI 互換性の前提

ScopedAnimation は、SwiftUI が修飾子とホストした内容にトランザクションを渡す挙動に依存します。
これは観測された挙動であり、すべての版で同じ伝播をするという Apple の保証ではありません。

[設計](../HANDOFF.md)がライブラリの契約を定義します。この文書は、その実現に必要な前提、実行可能な検証、根拠の限界を記録します。

## 互換性の判定条件

| 前提 | 必要な挙動 | 自動テスト |
| --- | --- | --- |
| 境界での除去 | animation を nil にすると、明示的・祖先の暗黙的アニメーションが内容に届く前に消える | `AnimationBarriersTests.swift`、`AnimationProxiesTests.swift` |
| ローカル復元 | 祖先フックが除去した後、子孫フックがアニメーションを設定できる | `AnimationAssumptionsTests.swift` |
| 明示的スタンプの伝播 | `withTransaction` のカスタムキーがルートと子孫に届く | `AnimationProxiesTests.swift` |
| ローカルな値のスタンプ | リゾルバーが上流には送らず、子孫にアニメーションとスタンプを渡せる | `AnimationValuesTests.swift` |
| 値ゲート | `.transaction(value:)` が監視値の変更で適用され、無関係な更新を動かさない | `AnimationAssumptionsTests.swift`、`AnimationUpdateSequenceTests.swift` |
| 入れ子の所有者 | 不一致のスタンプを保持してアニメーションを除去し、一致する子孫が復元できる | `AnimationProxiesTests.swift`、`AnimationBarriersTests.swift` |
| 診断配置 | ルートは明示的トランザクションを観測するが、下の値修飾子が生成するものは見えない | `AnimationDiagnosticCoverageTests.swift` |
| 内容の同一性 | 要素数変更で状態を維持し、新しい比較基準を設定する | `AnimationTriggersTests.swift`、`AnimationUpdateSequenceTests.swift` |

ファイルは `Tests/ScopedAnimationTests/` 以下です。直列のメインアクタースイートでホストを保持し、
アニメーションがないと判定する前にも spy による観測を必須にします。

除去・復元・スタンプ伝播が対象ランタイムで成立しなければ、依存する実装を止め、再現例と設計を確認します。
フレームワークの非互換性を隠すために公開意味論を変更してはいけません。

## 観測の方向

```text
withTransaction(アニメーション + スタンプ)
    ├─ ルートがスタンプを観測できる
    └─ 子孫がスタンプを観測できる

ルートの観測器
    └─ ローカルな値アニメーション + スタンプ
        └─ 子孫がスタンプを観測できる
```

この違いにより、ルート検出器は直接の `.animation(_:value:)` をすべて見つけられません。
疑わしい発生源の下流に検出器を置くか、拒否する領域にバリアを置きます。

## 基礎検証の記録

環境：**2026-07-03**、Xcode 26.5 (17F42)、Apple Swift 6.3.2、iPhone 17 Simulator、iOS 26.5。
独立した `SwiftAnimationSpike` パッケージで SwiftUI のフックを直接検証しました。
探索用パッケージはこのリポジトリには配布していません。維持する検証は上表のテストです。

実行コマンド：

```sh
xcodebuild test -scheme SwiftAnimationSpike -destination 'platform=iOS Simulator,name=iPhone 17'
```

実出力の抜粋です。S1〜S6 は、順に除去、ローカルアニメーション、スタンプ、観測、ホストしたコンテナ、境界形状を識別します。

```text
S1_EXPLICIT: seq=1 label=explicit-barrier animation=false stamp=nil disables=false | seq=2 label=explicit-control animation=true stamp=nil disables=false
S1_IMPLICIT: seq=3 label=implicit-barrier animation=false stamp=nil disables=false | seq=4 label=implicit-control animation=true stamp=nil disables=false
S2_OUTER: seq=1 label=s2 animation=false stamp=nil disables=false
S2_INNER: seq=2 label=s2 animation=true stamp=nil disables=false
S3_WITH_TRANSACTION: seq=1 label=root animation=true stamp=with-transaction disables=false | seq=2 label=with-transaction-child animation=true stamp=with-transaction disables=false
S3_VALUE_STAMP: seq=3 label=root animation=false stamp=nil disables=false | seq=4 label=value-child animation=true stamp=value-driven disables=false
S4_METRICS rootCalls=5 rowCalls=300 elapsedMs=206.62
S4_IMPLICIT_DESCENDANT: seq=306 label=root animation=false stamp=nil disables=false | seq=307 label=implicit-descendant animation=true stamp=nil disables=false
S5_TRANSITION: seq=2 label=list-container animation=false stamp=nil disables=false | seq=3 label=transition-container animation=true stamp=nil disables=false
S5_LIST_LAZY_COUNTS listContainer=1 listRows=0 lazyRows=10 listAnimated=0 lazyAnimated=0
S6_GEOMETRY: #0:16.0,1472.0,358.0,44.0 #1:16.0,146.0,358.0,44.0 #2:16.0,146.0,812.0,44.0
TEST SUCCEEDED
```

観測から確認できたこと：

- 対照ビューにアニメーションが届く状況で、境界がそれを除去した。
- ローカルな値変更は境界内にアニメーションを与えた。
- 明示的スタンプはルートと子に届き、値駆動スタンプは子だけに届いた。
- 60 行への 5 回の更新で 300 回の行コールバックが発生した。経過時間にはランループ処理を含み、CPU ベンチマークではない。
- List コンテナと遅延生成の行は観測できたが、List 行のコールバックはなかった。
  ゼロ件の観測では、行単位の遮断や再利用を確認できない。
- スクロールとホストのサイズ変更に応じて、追跡するオーバーレイのフレームが変化した。

## ホストテストだけでは確立できないこと

渡されたアニメーションとスタンプは検証できますが、補間、描画フレーム、フレームレートは測りません。
トランジションや matched geometry も、アプリ固有の表示を目視で確認する必要があります。

[サンプル QA](../Examples/QA.md)で、List の伝播、バリア、再利用、枠線、操作を確認します。
記録結果は指定した環境にだけ適用され、サンプルのビルド成功は代わりになりません。

再実行は[貢献ガイド](../CONTRIBUTING.md)、環境と出力は[検証記録](validation.md)を参照してください。
