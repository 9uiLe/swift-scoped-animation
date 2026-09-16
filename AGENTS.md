# AGENTS.md — コーディングエージェント向け指示

このリポジトリは OSS の SwiftUI ライブラリ `swift-scoped-animation`、モジュール名は `ScopedAnimation` です。
**`HANDOFF.md` が製品スコープ・API 設計・ロードマップの唯一の設計基準です。コードを書く前に読んでください。**

## 基本ルール

- 公開 API・意味論・ロードマップの段階を独断で変更しないでください。
  `HANDOFF.md` の設計に誤りや実現不可能な点がある場合は、試作コードと根拠を示して報告します。
  合意した設計は同じ PR で `HANDOFF.md` に反映してください。
- HANDOFF 第 9 節の依存順序に従います。境界での除去、ローカルな復元、スタンプ伝播を検証してから、
  それらに依存する実装へ進んでください。前提が崩れた場合は再現例を報告し、黙って設計を変えないでください。
  互換性の判定条件は `docs/swiftui-assumptions.md` を参照します。
- テスト成功を報告するときは、実際の `swift test` / `xcodebuild test` 出力を必ず貼ってください。
  検証できない項目は明記してください。
- `Package.swift` の外部依存はゼロです。これは製品要件です。
- 日本語を基本言語とします。文書・コメント・診断・エラー・サンプル UI・Issue/PR・コミットメッセージは日本語で記述します。
  英語版を提供する文書、識別子やログの扱いは `CONTRIBUTING.md` の言語方針に従ってください。
  コミットメッセージには、変更内容に加えて変更の動機を記録します。

## 情報を長く維持できる場所に置く

- **コードには実現方法を置く。** 名前・型・制御フローで仕組みを表現します。
  動作を逐語的に説明するコメントを追加せず、命名や構造を改善してください。
- **テストには要求する挙動を置く。** テスト名・準備・アサーションで製品が約束する挙動を表現します。
- **コミット履歴には変更理由を置く。** 差分の要約だけでなく、変更が必要になった動機と背景を残します。
- **実装コメントには採用できない理由を置く。** 単純な実装を採れない非自明な制約や、
  コードでは表せない代案の棄却理由がある場合だけ記述します。

必須の DocC コメントは API の公開契約と使い方を説明するもので、実装の実況ではありません。
長く維持する製品・API の判断は `HANDOFF.md` に置きます。

## ツールチェーンと対象

- Xcode 26.x / Swift 6.3、Swift 6 言語モード、strict concurrency = complete
- iOS 17+、macOS 14+、tvOS 17+、watchOS 10+、visionOS 1+
- SwiftPM のみ。CocoaPods・Carthage は使用しません。

## ビルドとテスト

```sh
swift build
swift test                          # macOS のホストテスト
python3 -m unittest discover -s scripts/tests -v  # リリースツール
# コアの意味論を変更した場合は iOS シミュレーターも必須です。
xcodebuild test -scheme ScopedAnimation \
  -destination 'platform=iOS Simulator,name=iPhone 17' | tail -50
```

上のシミュレーターがなければ、`xcrun simctl list devices available` で一覧を確認し、
最新の iPhone を選んでください。使用したデバイス名は PR 本文に記録します。

## コードスタイル

- `.swift-format` の設定を使用します。標準スタイル、行長 100 文字です。
  CI は `swift format lint --strict` を実行します。
- 公開 API のすべてに DocC コメントを付け、公開型には短い使用例を添えます。
  シグネチャを言い換えただけの `///` は不要です。
- 診断処理はすべて `#if DEBUG` で囲み、RELEASE から完全に除去します。
  `swift build -c release` でも確認してください。
- ライブラリでは強制アンラップ・強制キャストを禁止します。`fatalError` はプログラマーの誤用に対する
  事前条件違反に限り、対処できるメッセージを付けます。
- SwiftUI の命名規約に従います。ビュー修飾子は `some View` を返す `View` 拡張、
  コンテナは `struct ... : View` とします。

## テスト規約

- Swift Testing（`import Testing`）を使用します。特定のホスティング要件で XCTest が必要な場合だけ例外とし、理由を記録します。
- トランザクション spy（HANDOFF 第 8 節）は `Tests/.../Support/` に置きます。
  バリア、値駆動スコープ、スタンプ、リーク検出には、それぞれ少なくとも 1 つの spy による振る舞いテストが必要です。
- 不安定なテストはバグです。`sleep` による待機を使わず、ランループを進めるか明示的な期待条件で待ちます。

## CI

GitHub Actions の Xcode 26.x を持つ macOS ランナーで、ビルド・macOS/iOS テスト・厳格なフォーマット検査・
DocC・RELEASE ビルドとテスト・診断シンボル監査・サンプルのビルドを実行します。
ランナーや Xcode を固定する前に、GitHub ホスト環境で実際に利用できるバージョンを確認してください。

## リリースツール

- 所有者がローカル認証で実行するコマンドは `docs/releasing.md` に定義します。
- `scripts/release.py` は Python 標準ライブラリの `unittest` で検証します。
  一時 Git リポジトリと模擬 GitHub 応答を使い、テストでタグや Release を公開してはいけません。
- CI は読み取り専用です。公開には、対象コミットの master push CI で、パッケージとリリースツールの両ジョブが成功している必要があります。
- `README.md` と `README.en.md` の導入バージョンを同時に更新・検証してください。

## PR ごとの完了条件

1. 厳格並行性チェックで警告なくビルドでき、ローカルテストが成功していること。実行ログを貼ること。
2. 新しい公開 API が DocC に記載され、サンプルで使用されていること。
3. `CHANGELOG.md` の `Unreleased` に変更を記載していること。
4. Issue へのリンクがない TODO/FIXME を残さないこと。
5. DEBUG 診断の追加・改名時は、`scripts/verify-release-diagnostics.sh` の存在確認用マーカーも更新すること。
6. 英語版を持つ文書の変更は、対応する版にも同じ PR で反映すること。
