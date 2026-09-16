# 貢献ガイド

日本語 | [English](CONTRIBUTING.en.md)

製品の契約を読み、変更する挙動の実装箇所を確認し、対応するホスティング環境で検証してください。

## 設計の基準

`HANDOFF.md` を製品スコープ・公開 API・ロードマップの唯一の設計基準とします。
公開 API、意味論、ロードマップの順序を変える場合は設計を更新し、PR に理由を記載してください。

## 言語方針

- 日本語を基本言語とします。設計文書、DocC、API コメント、実装コメント、診断・エラーメッセージ、
  サンプル UI、Issue/PR、コミットメッセージは日本語で記述します。コミットには変更の動機も残してください。
- 海外の利用者・貢献者向けに `README.en.md`、`CONTRIBUTING.en.md`、`SECURITY.en.md`、
  `CODE_OF_CONDUCT.en.md` を提供します。日本語版と相互リンクし、対応する変更は同じ PR で反映します。
- 英語での Issue や PR も受け付けます。英語版を持たない設計・運用文書は日本語を参照してください。
- API・型・変数・ファイル名・CLI サブコマンド・機械判定用の識別子は英語のまま維持します。
  CI の必須ジョブ名、CHANGELOG の `## Unreleased` とバージョン見出し、DocC の `Overview`・`Topics`・
  `Parameter` などの構文も維持します。
- 実行ログ、過去の計測値、外部文書の引用は原文を保持します。`LICENSE` は MIT ライセンスの英語原文を使用します。
- 英語 README の導入バージョンは日本語版と一致させます。リリースコマンドが両方を更新・検証します。

公開文書では、ライブラリを**アニメーションの遮断と検出**として説明してください。
状態更新やすべてのアニメーションをスコープ内に閉じ込める保証はありません。

## リポジトリ構成

| パス | 責務 |
| --- | --- |
| `Sources/ScopedAnimation/` | スコープの構成、トリガー解決、境界、プロキシ、スタンプ |
| `Sources/ScopedAnimation/Diagnostics/` | DEBUG 警告、リーク検出、オーバーレイ |
| `Sources/ScopedAnimation/Documentation.docc/` | 公開 API のガイド |
| `Tests/ScopedAnimationTests/` | 振る舞いと純粋な契約のテスト |
| `Tests/ScopedAnimationTests/Support/` | ホスティング、トランザクション記録、テスト用データ |
| `Examples/ScopedAnimationExample/` | 操作できる iOS サンプル |
| `Examples/QA.md` | 手動 QA の手順と環境ごとの結果 |
| `Benchmarks/` | 内部 CPU コストの計測用コードと手順 |
| `docs/` | 互換性の前提、参考計測、検証記録、リリース手順 |

[設計](HANDOFF.md)に各要素の責務を、[検証記録](docs/validation.md)に検証範囲と制約を記載しています。

## 開発環境

- Xcode 26.x / Swift 6.3
- SwiftPM のみ、外部依存なし
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

## API ドキュメントと診断

公開 API には DocC コメントを付けます。診断の実装はすべて `#if DEBUG` で囲んでください。
RELEASE 成果物からの除去を確認するときは、DEBUG には対象が存在することも確かめ、
`strings` または `nm` でバイナリを検査します。

## テスト

振る舞いのテストは `Tests/ScopedAnimationTests/` で契約ごとにまとめています。
ホストビュー、モデル、トランザクション記録用の spy は `Support/` に置きます。

Swift Testing を使ってください。ホスティングや警告の捕捉を伴うテストは、直列実行する
`AnimationScopeBehaviorTests` スイートに追加します。ランループの更新とグローバルな警告出力先の
差し替えを重複させないためです。ホストは保持し、`defer` で閉じてください。

「アニメーションしない」と主張する前に、トランザクションを観測する必要があります。
記録が空なら失敗とし、`Animation` 値を直接比較します。所有者の検証では、同じ記録のアニメーションと
スタンプを確認してください。トリガー選択や上限付きデバウンスの純粋なテストは、SwiftUI のホスティングに依存させません。

## 性能計測

ビルドやシミュレーターを同時実行せず、`bash scripts/benchmark-performance.sh release` と
`bash scripts/benchmark-performance.sh debug` を順番に実行します。
[計測手順](Benchmarks/README.md)に従い、コンパイラ設定、環境、操作の定義、生の計測値を記録してください。
内部の CPU 時間から、フレームレートやアロケーションの改善を推定しないでください。

## リリース

所有者がローカルの `scripts/release.py` で準備 PR を作り、マージ後のコミットを検証して、
注釈付きタグと GitHub Release を公開します。GitHub Actions は読み取り権限でコミットを検証します。

```sh
./scripts/release.py prepare X.Y.Z --dry-run
./scripts/release.py prepare X.Y.Z
# 準備 PR をマージし、master の push CI 完了を待ちます。
./scripts/release.py check X.Y.Z
./scripts/release.py publish X.Y.Z
```

`X.Y.Z` を選んだ安定版バージョンに置き換えてください。タグは `vX.Y.Z` です。
公開には、対象 SHA の `build-test-docs` と `Release tooling checks` の成功、
両言語の README と CHANGELOG のバージョン一致、GitHub の Immutable releases 有効化が必要です。

認証、保護設定、コマンドの動作、再開方法は[リリース手順](docs/releasing.md)を参照してください。
`scripts/release.sh` も同じサブコマンドを Python に渡します。
