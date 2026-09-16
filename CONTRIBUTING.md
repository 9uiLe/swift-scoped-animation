# 貢献ガイド

日本語 | [English](CONTRIBUTING.en.md)

ScopedAnimation の開発では、製品の契約、実装、検証結果を対応付けて管理します。
API の利用は [README](README.md)、製品スコープ・公開 API・意味論・ロードマップは [HANDOFF.md](HANDOFF.md) を参照してください。

## 開発の進め方

1. 設計書で対象の契約を確認し、対応する実装とテストを読む。
2. 公開 API・意味論・ロードマップの順序を変える場合は、設計書を更新して PR に理由を示す。
3. 実装と契約のテストを変更し、DocC と必要な文書をそろえる。
4. 利用者向けの変更を `CHANGELOG.md` の `## Unreleased` に記録する。
5. 検証を実行し、PR に環境・実出力・未検証範囲を記載する。

ライブラリの契約は**アニメーションの遮断と検出**です。状態変更はスコープ外のビューも更新し、
プロキシのトランザクションは境界のない領域にも届きます。文書やテストもこの範囲に合わせます。

## 言語方針

日本語を基本言語とします。英語での Issue・PR・報告も受け付けます。

| 対象 | 記述言語と管理方法 |
| --- | --- |
| 設計、運用文書、DocC、API・実装コメント | 日本語 |
| 診断、エラー、CLI の案内、サンプル UI、テストの表示名 | 日本語 |
| Issue、PR、コミットメッセージ | 日本語を基本とし、コミットには変更の動機も記録 |
| README、貢献ガイド、セキュリティ方針、行動規範 | 日本語版と `.en.md` の英語版を提供 |
| API・型・変数・ファイル名、CLI サブコマンド、機械判定用の識別子 | 英語 |
| 実行ログ、計測値、外部文書の引用、MIT ライセンス | 原文を保持 |

英語版は利用と参加に必要な同じ契約を説明し、相互リンクで切り替えられるようにします。
対応する内容は同じ PR で更新します。設計・運用の詳細ガイドと DocC は日本語で管理します。

次の表記はツールが参照するため固定します。

- 必須 CI ジョブ名：`build-test-docs`、`Release tooling checks`
- CHANGELOG の見出し：`## Unreleased`、`## X.Y.Z - YYYY-MM-DD`
- DocC 構文：`Overview`、`Topics`、`Parameter` など

両 README の導入バージョンは一致させます。リリースコマンドが両方を更新し、欠落・重複・不一致を検証します。

## 情報の配置

| 情報 | 管理する場所 |
| --- | --- |
| 製品スコープ、API 契約、内部の責務、ロードマップ | `HANDOFF.md` |
| 導入と API の使い方 | README、DocC、公開 API の DocC コメント |
| 実現方法 | コードの名前・型・制御フロー |
| 要求する挙動 | テスト名・準備・アサーション |
| 変更の動機 | コミット履歴 |
| 単純な実装を採れない非自明な制約 | 実装コメント |
| 利用者に関係する変更と移行手順 | `CHANGELOG.md` |
| 環境・対象ソース・実出力・観測の限界 | `docs/validation.md`、性能・QA の記録 |

設計や使用ガイドは、用語と前提を文書内で説明します。会話、過去の PR、変更作業の順序を知らなくても読める内容にします。
検証記録には日付と適用範囲を明記し、その実行が確認した範囲を示します。

## リポジトリ構成

| パス | 責務 |
| --- | --- |
| `Sources/ScopedAnimation/` | スコープ構成、値の解決、境界、プロキシ、スタンプ |
| `Sources/ScopedAnimation/Diagnostics/` | DEBUG 警告、リーク検出、オーバーレイ |
| `Sources/ScopedAnimation/Documentation.docc/` | 公開 API のガイド |
| `Tests/ScopedAnimationTests/` | 契約ごとの振る舞いテストと純粋なテスト |
| `Tests/ScopedAnimationTests/Support/` | ホスティング、トランザクション記録、テスト用データ |
| `Examples/ScopedAnimationExample/` | 操作できる iOS サンプル |
| `Examples/QA.md` | 手動 QA の手順と観測結果 |
| `Benchmarks/` | 内部 CPU コストの計測用コードと手順 |
| `scripts/`、`scripts/tests/` | リリース・計測・診断監査のコマンドとリリースツールのテスト |
| `docs/` | 互換性の前提、参考計測、検証記録、リリース手順 |

## 開発環境

- Xcode 26.x / Swift 6.3
- SwiftPM、外部依存なし
- Swift 6 言語モード、完全な厳格並行性チェック
- リリースツールのテストには Python 3.10+（標準ライブラリのみ）

## ローカルでの検証

PR を作成する前に実行してください。

```sh
python3 -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh

swift format lint --strict --configuration .swift-format \
  Package.swift \
  Benchmarks/*.swift \
  Sources/ScopedAnimation/*.swift \
  Sources/ScopedAnimation/Diagnostics/*.swift \
  Tests/ScopedAnimationTests/*.swift \
  Tests/ScopedAnimationTests/Support/*.swift \
  Examples/ScopedAnimationExample/ScopedAnimationExample/*.swift

swift build
swift test
xcodebuild test -scheme ScopedAnimation -destination 'platform=iOS Simulator,name=iPhone 17'
swift build -c release
swift test -c release
bash scripts/verify-release-diagnostics.sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS'
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

`iPhone 17` がなければ、利用できる最新の iPhone シミュレーターを選び、デバイス名を記録してください。


CI は読み取り権限でパッケージとリリースツールを検証します。コマンドの成功を報告するときは実出力を添え、
実行していない項目は明記してください。手動 QA は [Examples/QA.md](Examples/QA.md) に従います。

## API ドキュメントと診断

すべての公開 API に契約と使い方を説明する DocC コメントを付け、公開型には短い例を添えます。
診断実装は `#if DEBUG` に限定します。診断の追加・改名時は、
`scripts/verify-release-diagnostics.sh` のマーカーも更新します。
監査は DEBUG に対象が存在することを確認したうえで、RELEASE バイナリの `strings` / `nm` 出力から不在を検証します。

## テストの設計

Swift Testing を使い、契約ごとにテストをまとめます。ホスティングや警告の捕捉を伴うケースは、
直列の `AnimationScopeBehaviorTests` スイートに置きます。ランループの更新とグローバルな警告出力先の差し替えが重ならないためです。
ホストは保持して `defer` で閉じ、待機にはランループか明示的な期待条件を使います。

トランザクション spy の記録が空なら、「アニメーションがない」というアサーションも失敗とします。
`Animation` 値を直接比較し、所有者を確認するときは同じ記録のスタンプも調べます。
値比較、トリガー選択、上限付きデバウンスの純粋なテストはホスティングから独立させます。

リリースツールは一時 Git リポジトリと模擬 GitHub 応答で検証します。テストで実際のタグや Release は公開しません。

## 性能計測

`bash scripts/benchmark-performance.sh release` と `bash scripts/benchmark-performance.sh debug` を順に実行します。
計測中はビルドやシミュレーターなどの高負荷処理を避けます。
[ベンチマーク手順](Benchmarks/README.md)に従い、環境、コンパイラ設定、操作の定義、生の値を記録してください。
内部 CPU 時間からフレームレートやアロケーション数の改善を推定せず、アプリは対象デバイスで計測します。

## リリース

所有者は、文書の準備 PR をマージし、そのソース SHA の master push CI を確認してから公開します。
認証、保護設定、拒否条件、再開方法は[リリース手順](docs/releasing.md)に定義しています。

```sh
./scripts/release.py prepare X.Y.Z --dry-run
./scripts/release.py prepare X.Y.Z
# 準備 PR をマージし、master の push CI 完了を待ちます。
./scripts/release.py check X.Y.Z
./scripts/release.py publish X.Y.Z
```

`X.Y.Z` は選んだ安定版の数値バージョンです。公開条件には、両必須ジョブの成功、CHANGELOG と両 README の一致、
GitHub の Immutable releases の有効化が含まれます。成果物は注釈付き `vX.Y.Z` タグとソースのみの GitHub Release です。
`scripts/release.sh` も同じサブコマンドを Python に渡します。
