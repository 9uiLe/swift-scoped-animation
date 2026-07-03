# HANDOFF — swift-scoped-animation (仮称)

対象読者: 実装担当エージェント(Codex)およびメンテナ。
このドキュメントが設計の一次ソース。API・セマンティクスを変更する場合は必ずこのファイルを更新し、変更理由を PR 説明に書くこと。

---

## 1. プロダクト定義

### 1.1 一行定義

SwiftUI のアニメーションに **構造的な境界(スコープ)** を導入し、「どこからどこまでがアニメーションするのか」をコード上・実行時の両方で可視化・強制する薄いライブラリ。

### 1.2 解決する問題

1. `.animation(_:value:)` / `withAnimation` の影響範囲がコードを読んでも分からない。modifier の位置と順序という「暗黙知」に依存しており、レビューで見落とされる。
2. `withAnimation` は状態を読んでいる **全ての** ビューに波及する。意図しない画面の隅がアニメーションする事故が起きやすい。
3. アニメーション対象のサブツリーが大きいほど、フレーム毎の再評価・再描画コストが増える。境界がないため「気づいたら画面全体が対象」になりがち。

### 1.3 解決しない問題(Non-goals)

- カスタムアニメーションカーブ・物理エンジン(SwiftUI 標準の `Animation` をそのまま使う)
- エフェクト集(Pow などの領域。競合しない)
- UIKit / AppKit サポート
- v0.1 では SwiftSyntax ベースの静的 lint プラグイン(§8 参照)

### 1.4 Apple 純正 API との差分(これが言えないなら出荷しない)

Apple は既に部分解を持つ: `.animation(_:value:)`(値スコープ)、iOS 17 の `.animation(_:body:)`(modifier チェーンスコープ)、`Transaction`。それでも残る問題:

| 純正の穴 | 本ライブラリの回答 |
|---|---|
| スコープが「modifier の付け位置」という暗黙情報で、構造として見えない | `AnimationScope { }` という **コンテナ** にする。インデントが境界になる |
| 祖先の `withAnimation` / implicit animation がサブツリーに漏れ込むのを防ぐ手段が散文的(`.transaction` を手書き) | スコープ境界で流入を自動遮断 + 単体の `.animationBarrier()` |
| 「スコープ外で発生したアニメーション」を検出する仕組みがない | `Transaction` への刻印(custom `TransactionKey`)+ DEBUG ビルドでのリーク検出(runtime warning) |
| アニメーション境界を実行時に目視確認できない | DEBUG 用オーバーレイでスコープ境界を色付き枠で描画 |

要するに **チーム開発でレビュー可能・強制可能にする規律レイヤー** が製品。機能追加ではなく制約の提供。

---

## 2. 名称・配布

- リポジトリ名(提案): `swift-scoped-animation`(現ディレクトリ名 `swift-animation` は一般的すぎるため GitHub 公開時に変更推奨。ローカルのディレクトリ名は据え置きで構わない)
- モジュール名: `ScopedAnimation`
- 配布: Swift Package Manager のみ。CocoaPods 非対応(明記する)
- ライセンス: MIT
- **外部依存ゼロ** を維持する(セールスポイント)。runtime warning も内製する(§5.3)

## 3. サポート範囲・ツールチェーン

- Swift 6 language mode、strict concurrency = complete
- 開発ツールチェーン: Xcode 26.x / Swift 6.3
- 最低 OS: **iOS 17 / macOS 14 / tvOS 17 / watchOS 10 / visionOS 1**
  - 根拠: 刻印方式の要である custom `TransactionKey` と `.transaction(value:)` が 17/14 世代必須。2026 年時点の新規 OSS として妥当な床

---

## 4. コア API(v0.1)

### 4.1 `AnimationScope` — 境界コンテナ(本体)

```swift
// (A) 値駆動: value が変化したときだけ、このサブツリーがアニメーションする
AnimationScope(.spring(duration: 0.3), value: isExpanded) {
    CardContent(isExpanded: isExpanded)
}

// (B) 明示トリガー駆動: proxy 経由の変更だけがアニメーションになる
AnimationScope(.snappy) { scope in
    CardContent(isExpanded: isExpanded)
        .onTapGesture {
            scope.animate { isExpanded.toggle() }
        }
}
```

セマンティクス(正確に実装すること):

1. **流入遮断(strip-then-restore)**: スコープ境界は流入 transaction からアニメーションを**常時**剥がす(刻印の有無を問わない)。外の `withAnimation` や implicit animation はスコープ内に届かない。
2. **(A) 値駆動**: 内部的に `.animation(_:value:)` 相当。`value` の変化に起因する更新のみアニメーションし、その transaction にスコープの刻印を打つ。**刻印が届くのはスコープ内の子孫のみ**(downstream-only。Phase 0 S3 で確認)。スコープより上の観測点からこのアニメーションは見えない。
3. **(B) 明示駆動**: `scope.animate {}` は `withTransaction` で「スコープ ID + 実際に使うアニメーション」を刻印した transaction を作って body を実行する。刻印はツリー全体(ルートの観測点を含む)に到達する。アニメーションを復元するのは**刻印のスコープ ID が一致する自スコープの境界のみ**。したがって proxy のアニメーションが適用されるのは自スコープのサブツリー内に限られ、**外側スコープの領域には適用されない**。`transaction.disablesAnimations == true` の場合は復元しない。
4. **ネスト**: 内側のスコープが勝つ。外側 proxy の transaction は内側境界で剥がされ、ID 不一致のため復元されない。内側 proxy の transaction は外側境界で一旦剥がされ、内側境界で復元される。
5. `.transition` はスコープ内の構造変化(if/switch)に対して期待通り動くこと(insertion/removal の transaction がスコープから供給される)。

```swift
public struct AnimationScopeProxy {
    /// スコープ既定のアニメーションで body を実行する
    public func animate(_ body: () -> Void)
    /// アニメーションを一時的に差し替える
    public func animate(_ animation: Animation, _ body: () -> Void)
}
```

### 4.2 `.animationBarrier()` — 遮断単体

```swift
LegacyDashboard()
    .animationBarrier()   // ここから先には何もアニメーションが届かない
```

- 祖先由来の transaction からアニメーションを剥がす。**刻印は保持する**(下流の `AnimationScope` が自分の刻印を復元できるようにするため。バリア自体は何も復元しない)。「この先は静的」の正確な意味は「**宣言なしのアニメーションはこの先に届かない**」であり、バリアの下に構造として明示された `AnimationScope` は値駆動・proxy 駆動とも機能し続ける。
- `AnimationScope` の流入遮断(剥がす側)は内部的にこれと同一実装を共有する。
- **DEBUG ではリークセンサーを兼ねる**: 剥がした transaction が「刻印なしのアニメーション付き」だった場合、runtime warning を発報する(刻印ありは外側スコープの正常なネストなので発報しない)。RELEASE では遮断のみ。オプトアウト引数を用意する。

### 4.3 重要な制約 — 正直に文書化すること

**`withAnimation`(および proxy 外での状態変更)の波及は SwiftUI の原理上、完全には閉じ込められない。** 本ライブラリができるのは (a) 境界での流入遮断、(b) 刻印による出所追跡、(c) 刻印なしアニメーションの検出・警告、の 3 点。「封じ込め」ではなく「遮断 + 検出」。さらに検出には精度差がある(§5.1 の精度マトリクス)。README・DocC でこのモデルと限界を明確に説明する。誇張した瞬間に信頼を失う。

---

## 5. 診断機能(v0.1、すべて DEBUG ビルド限定)

### 5.1 リーク検出

```swift
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .detectAnimationLeaks()   // ルート推奨。任意のサブツリーにも置ける。DEBUG のみ有効
        }
    }
}
```

- 観測点を通過する「刻印なしのアニメーション付き transaction」を Xcode の runtime warning(紫の Issue)として発報する。メッセージには可能な範囲で発生源のヒントを含める。
- **検出精度(Phase 0 S3/S4 実測に基づく。README / HowItWorks にもこの表を載せること)**:

| リーク源 | ルートの検出器 | サブツリー検出器 / barrier センサー |
|---|---|---|
| 生の `withAnimation` / 刻印なし `withTransaction` | 検出できる(高信頼) | 検出できる |
| スコープ外の生の `.animation(_:value:)` | **検出できない**(transaction が観測点より下で生成される) | 発生源より下流に観測点があれば検出できる |
| スコープ由来(刻印あり) | 発報しない(正常) | 発報しない(正常) |

- 生 `.animation(_:value:)` の盲点は三層で補う: (a) barrier センサー(§4.2)、(b) 疑わしいサブツリーへの `detectAnimationLeaks()` 設置、(c) Phase 2 の SwiftLint ルール(生 `.animation(` を静的に禁止)。この三層構造を README / HowItWorks で図解する。
- 実装方針: `.transaction {}` フックで観測。フック呼び出し回数はサブツリー規模に比例する(S4 実測: 60 行 × 5 更新で 300 回)ため、**検出フックは粗い粒度(ルート・画面単位)に置く前提で設計し、行単位への自動設置は絶対にしない**。RELEASE では完全に消えること(`#if DEBUG` + inlinable no-op)。
- 同一箇所からの連続発報はデバウンスする(ログ洪水はそれ自体が採用障壁)。

### 5.2 境界オーバーレイ

```swift
RootView()
    .animationScopeDebugOverlay()   // スコープ境界を色付き枠 + ラベルで描画
```

- 各 `AnimationScope` が anchor preference で自分の矩形とラベル(任意の `name:` 引数)を登録し、ルートで枠を描画する。
- **これがデモ・README の主役になる機能。** 見た目の分かりやすさに投資すること。

### 5.3 runtime warning の内製

Point-Free の issue-reporting 相当の最小実装(`os_log` の dso トリックで紫警告を出す)を internal に持つ。外部依存は追加しない。実装は 1 ファイルに閉じる。

---

## 6. パフォーマンスに関する立場(重要)

「perf 制約の強制」はライブラリでは原理的にほぼ不可能。v0.1 での現実的な貢献は:

1. **境界を小さく保つ文化の強制**: barrier-by-default の設計思想により、アニメーション対象サブツリーが自然に最小化される(これが最大の perf 貢献であり、定量的な主張はしない)。
2. **DocC 記事 "Animation Performance Playbook"**: 何をアニメーションすべきか(opacity / scale / offset / rotation)、何を避けるか(layout に響く frame / padding / font、blur / shadow)、Instruments の SwiftUI テンプレートでの計測手順。
3. 静的検出(「layout プロパティをアニメーションしたら警告」)は **やらない**。SwiftUI の型システムでは判定不能であり、中途半端な検出は誤検知でユーザーを失う。

README では「performance guardrails」ではなく「scoping discipline that keeps animated subtrees small」という表現に留めること。

---

## 7. リポジトリ構成

```
.
├── Package.swift
├── Sources/ScopedAnimation/
│   ├── AnimationScope.swift
│   ├── AnimationScopeProxy.swift
│   ├── AnimationBarrier.swift
│   ├── TransactionStamp.swift          // TransactionKey・刻印
│   ├── Diagnostics/
│   │   ├── LeakDetection.swift
│   │   ├── DebugOverlay.swift
│   │   └── RuntimeWarning.swift
│   └── Documentation.docc/
│       ├── ScopedAnimation.md          // ランディング
│       ├── GettingStarted.md
│       ├── HowItWorks.md               // transaction モデルの説明(§4.3 の制約含む)
│       └── PerformancePlaybook.md
├── Tests/ScopedAnimationTests/
├── Examples/ScopedAnimationExample/    // iOS サンプルアプリ(Xcode プロジェクト)
├── docs/
│   └── spike-findings.md               // Phase 0 の成果物
├── .github/workflows/ci.yml
├── LICENSE / README.md / CONTRIBUTING.md / CHANGELOG.md / .spi.yml
└── AGENTS.md / HANDOFF.md
```

---

## 8. ロードマップ

### Phase 0 — スパイク(✅ 完了 2026-07-03 / 判定: Go)

結果: S1 ✓ / S2 ✓ / S3 条件付き / S4 条件付き / S5 条件付き / S6 ✓。詳細は `docs/spike-findings.md`。
S3(刻印は downstream-only)と S4(ルート検出の盲点)の帰結は §4.1・§4.2・§5.1 に反映済み。S5 の List 行レベル検証はユニットホスティングでは観測不能だったため、Phase 1 の QA 項目に移管した(下記チェックリストと §10-5)。

以下の検証マトリクスは記録として残す:

このライブラリは SwiftUI の `Transaction` の未文書挙動に依存する。**本実装の前に、使い捨てコードで以下を検証し、`docs/spike-findings.md` に結果を書くこと。**

検証マトリクス(それぞれ「動く / 動かない / 条件付き」と再現コードを記録):

- S1: `.transaction { $0.animation = nil }` は祖先の `withAnimation` 由来のアニメーションを子孫から確実に剥がせるか。implicit `.animation(_:value:)` 由来ではどうか
- S2: S1 の遮断の内側で `.animation(_:value:)` を再適用すると、値駆動アニメーションだけが復活するか(modifier の適用順の依存関係を明確化)
- S3: custom `TransactionKey` による刻印は `withTransaction` から子孫の `.transaction {}` フックまで到達するか。`.animation(_:value:)` が生成する transaction にも刻印を差し込めるか(→ 不可なら値駆動スコープの刻印方式を再設計)
- S4: ルートの `.transaction {}` フックによるリーク観測は現実的か(呼び出し頻度、DEBUG でのオーバーヘッド)
- S5: `.transition` / `matchedGeometryEffect` / `List`・`LazyVStack` のセル再利用と barrier の相互作用で壊れるものはないか
- S6: anchor preference によるオーバーレイ描画はスクロール中・回転時に追従するか

**S1〜S3 のいずれかが不成立の場合は実装に進まず、findings と代替案(例: 刻印なしで barrier + 値駆動のみの縮小版)を報告して停止すること。**

### Phase 1 — v0.1.0(コア)

- [x] **S7 検証(strip-then-restore の前提。最初にやる)**: 境界の `.transaction {}` フックで `transaction.animation` に非 nil を代入してアニメーションを復元できることを spy テストで確認する。
- [x] `AnimationScope`(値駆動 + proxy 駆動)、`.animationBarrier()`、刻印(§4.1 strip-then-restore セマンティクス)
- [x] `detectAnimationLeaks()`(ルート/サブツリー両対応)+ runtime warning 内製
- [x] `.animationBarrier()` の DEBUG リークセンサー(§4.2)
- [x] `animationScopeDebugOverlay()`
- [x] テスト(§9)
- [x] **List 検証(最優先の QA)**: サンプルアプリに検証画面を作り、(1) `AnimationScope` で `List` を包んだとき行コンテンツまでアニメーションが届くか、(2) barrier が行内へのアニメーション流入を遮断するか、(3) セル再利用後もスコープ挙動が維持されるか、を目視確認して `Examples/QA.md` に記録する。
- [x] README / HowItWorks に検出精度マトリクス(§5.1)と三層の補完戦略を掲載
- [x] DocC 一式(§7 の 4 記事)
- [x] CI(§AGENTS.md)、LICENSE、README、CONTRIBUTING、CHANGELOG、.spi.yml
- [x] README: GIF プレースホルダ

### Phase 2 — v0.2(v0.1 出荷後に別途判断)

- 複数値トリガー(`value:` の可変長 / タプル対応)
- `.transition` 用ヘルパー
- SwiftLint `custom_rules` 設定例のドキュメント提供(生 `withAnimation` / `.animation` の使用を CI で禁止するチーム向け)。SwiftSyntax プラグインはビルド時間・バージョン追従コストが重いので採用しない
- visionOS / watchOS の実機検証マトリクス拡充

---

## 9. テスト戦略

SwiftUI のアニメーションは直接テストできない。以下の 2 層で担保する:

1. **Transaction spy テスト(主力)**: テスト専用の `.transaction {}` フックで、状態変更時にサブツリーへ流れた transaction(animation の有無・刻印の有無)を記録して assert する。`UIHostingController` にホストし、`@MainActor` でランループを回す。スコープの「遮断」「値駆動」「刻印」「バリア」はすべてこの方式で検証可能(Phase 0 で成立を確認済み)。ただし `List` の行レベルはこのハーネスでは観測できない(S5: 行フックが呼ばれない)ため、`List` のカバレッジはサンプルアプリの手動 QA で担保する。`LazyVStack` は spy テストで観測可能。
2. **純ロジックの単体テスト**: 刻印・デバウンス・オーバーレイの preference 集約などの純粋部分。

やらないこと: アニメーション中間フレームのスナップショットテスト(フレーク源)。見た目の確認はサンプルアプリの手動 QA チェックリスト(`Examples/QA.md`)で代替する。

**テストが書けない/通らない場合に「テスト済み」と報告することを禁ずる。** 実行ログを PR に貼ること。

---

## 10. 既知のリスク(メンテナの正直な評価)

1. **セマンティクスの土台が未文書挙動**: `Transaction` の伝播は Apple が保証する契約ではない。OS メジャーアップデートで挙動が変わるリスクを README に明記し、CI を最新 beta でも回す。
2. **「制約を課す」ライブラリは採用されにくい**: 機能ではなく規律を売る製品はデモ映えしない。採用の鍵はオーバーレイとリーク検出の「見せられる」体験。ここの完成度を落とさない。
3. **`withAnimation` は封じ込め不能**(§4.3)。ドキュメントの言葉選びを誤ると誇大広告になる。
4. **iOS 17 床**: 16 以下を切る判断。規律系ライブラリは新規コードベースから採用されるので許容と判断した。異論があればメンテナに確認。
5. **`List` の transaction 伝播が未証明**(Phase 0 S5): `List` は UIKit(UICollectionView)に再ホストするため、スコープ/バリアの効果が行コンテンツに及ぶかは未観測。及ばない場合、「行の内側にスコープを置く」という使用制約になる。iOS アプリで最頻出のコンテナであり、ここが崩れると製品価値が大きく削れるため、Phase 1 の最初の QA で潰すこと。
6. **ルート検出器の盲点**(Phase 0 S3/S4): スコープ外の生 `.animation(_:value:)` はルートから見えない。三層戦略(§5.1)で補うが、「すべてのリークを検出できる」とは決して謳わないこと。
