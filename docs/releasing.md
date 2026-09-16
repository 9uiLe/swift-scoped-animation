# リリースの設計と運用

ScopedAnimation は `9uiLe/swift-scoped-animation` からソースのみで配布する Swift パッケージです。
所有者 `9uiLe` がバージョンを選び、GitHub Actions で検証されたコミットを公開します。
公開用の認証情報は、所有者のローカル GitHub CLI で管理します。

## リリースの契約

注釈付き `vX.Y.Z` Git タグと GitHub Release を作成します。
タグは SwiftPM が利用するソースコミットを直接指します。Release のタイトルは `X.Y.Z`、
本文は CHANGELOG の該当バージョンの節です。バイナリは添付しません。

**リモートタグを作った時点で、SwiftPM からそのバージョンを利用できます。**
公開の前提はタグ作成前に確認します。Release は下書きで作り、タグとの整合性を検証してから公開します。

| 責務 | 担当 |
| --- | --- |
| 安定版の選択、準備 PR のレビュー・マージ、公開の開始 | 所有者 `9uiLe` |
| 文書のバージョン更新と公開条件の検証 | ローカルの `scripts/release.py` |
| パッケージ・リリースツールの検証 | 読み取り専用の GitHub Actions |
| 書き込み制限と公開成果物の固定 | GitHub の保護設定と Immutable releases |

タグは `v` 付き、コマンド引数と両言語の README は数値の `X.Y.Z` を使用します。
プレリリース、ビルドメタデータ、先頭ゼロ、引数の `v` 接頭辞は拒否します。
API 互換性に応じて手動でバージョンを選んでください。

## コマンド

Python 3.10+、Git、現在の GitHub CLI を用意し、変更のない作業ツリーで実行します。

```sh
gh auth login --hostname github.com
gh auth switch --hostname github.com --user 9uiLe
```

API で実際の認証ユーザーを確認します。`GH_TOKEN` などの環境変数は保存済み CLI 認証より優先されます。
`origin` は上流リポジトリの HTTPS URL、または `git@github.com:9uiLe/swift-scoped-animation.git` としてください。
fetch/push は同じ GitHub CLI 認証を使う HTTPS で行うため、origin が SSH でも SSH 鍵は不要です。
GitHub Actions 内での実行は拒否します。

`X.Y.Z` を選んだ安定版バージョンに置き換えます。

| コマンド | 動作 |
| --- | --- |
| `./scripts/release.py prepare X.Y.Z --dry-run` | ソースとタグを取得し、準備条件を検証して SHA とリリースノートを表示 |
| `./scripts/release.py prepare X.Y.Z` | `release/X.Y.Z` で文書を更新・push し、master 向けの PR を作成 |
| `./scripts/release.py check X.Y.Z` | 公開条件を検証し、SHA・該当 CI の URL・ノートを表示 |
| `./scripts/release.py publish X.Y.Z` | 再検証し、タグと下書きを作成または再開して、公開後の状態を検証 |

`prepare --dry-run` と `check` は取得済み参照を更新しますが、作業ファイル・作業ブランチ・リモート状態を変更しません。
`scripts/release.sh` も同じサブコマンドを Python に渡します。サブコマンドなしの呼び出しは拒否します。
文書の更新と公開を一度に行うコマンドはありません。

## 1. 準備 PR を作成する

`CHANGELOG.md` の `## Unreleased` に利用者向けの変更を記載します。
破壊的変更と移行手順は明示してください。GitHub に転記するため、ノート内のリンクは絶対 URL にします。
`Unreleased` と `## X.Y.Z - YYYY-MM-DD` は解析用の固定表記で、本文と小見出しは日本語です。

準備は作業中のブランチによらず、取得した `origin/master` を読みます。条件は次のとおりです。

- 認識できるすべての安定版タグと CHANGELOG の最新バージョンより新しいこと
- 先頭に `Unreleased` が 1 つあり、変更項目があること
- リリース見出しの日付が正しく、バージョンが重複せず新しい順であること
- `README.md` と `README.en.md` にパッケージの導入宣言がそれぞれ 1 つあり、最新の CHANGELOG と一致すること
- 対象のタグ、Release、ローカル・リモートの `release/X.Y.Z` ブランチが存在しないこと

空の Unreleased を残し、日付付き見出しを挿入し、両 README を更新します。
この 3 ファイルを選んだソース SHA 上でコミットし、ブランチを push して PR を作ります。
Swift ソース、パッケージ要件、既存のリリース節は変更しません。バージョン選択や公開も自動では行いません。

## 2. マージし、対象コミットの CI を待つ

ノートと導入バージョンを確認して準備 PR をマージします。
文書だけの変更も含め、master のすべての push でワークフローが実行されます。

公開には、そのソース SHA の最新の実行・再試行で、`build-test-docs` と `Release tooling checks` が
成功している必要があります。PR のチェック、手動実行、過去の成功、別コミットの成功は代用できません。

失敗・キャンセルされた場合は原因を解消して同じ CI を再実行するか、修正した準備 PR をマージします。
成功した再試行は公開条件を満たせます。

## 3. 検証して公開する

`check` で対象とノートを確認し、`publish` を実行します。
公開時は保存した計画を再利用せず、条件を再検証します。

| 検証対象 | 条件 |
| --- | --- |
| アカウント・リポジトリ | 認証ユーザーが `9uiLe`、上流が公開リポジトリで master を使用し、ユーザーに管理者権限がある |
| 作業ツリー | 追跡・未追跡の変更がない |
| 成果物保護 | Immutable releases が有効 |
| ソース | 取得した master の履歴に含まれる完全なコミット SHA |
| 文書 | 最新 CHANGELOG と両 README が対象バージョンに一致し、ノートがあり、日付が正しく、Unreleased が空 |
| CI 実行 | 有効な `ci.yml`、上流リポジトリ、push イベント、master、対象 SHA、最新の実行・再試行が一致 |
| CI ジョブ | 必須ジョブが各 1 つあり、成功し、ソース SHA も一致 |
| 既存タグ | コミットを直接指す注釈付き `vX.Y.Z`。入れ子や軽量タグは拒否 |
| 既存 Release | タグ・SHA・タイトル・所有者・ノートが一致し、プレリリースでも添付付きでもない。公開済みなら不変である |

新しいタグは、取得した `origin/master` の先端を指します。作成直前にリモート master が変わっていないか再確認します。
タグが既にある場合は、master が進んでもそのタグのコミットを使います。

未公開のバージョンは他の安定版タグより新しい必要があります。
`v` あり・なしの両方を比較するため、`0.3.0` と新しい `v0.3.0` が別名で重複することを防ぎます。

タグは作成後・公開前・公開後に確認します。下書きの内容も公開前に計画と照合します。
最終状態が公開済みかつ不変であることを確認し、成功時に URL を表示します。

## 中断からの復旧

### 公開

原因を解消した後、同じバージョンで `publish` を再実行します。

| リモート状態 | 動作 |
| --- | --- |
| タグも Release もない | 現在の master を検証して開始 |
| 一致する注釈付きタグ | タグのコミットと CI を検証し、下書きを作成 |
| 一致する下書き | タグ・ソース・内容・CI を検証して公開 |
| 一致する公開済みの不変な Release | ソースと内容を検証し、書き込みなしで URL を表示 |
| 不一致のタグまたは Release | 停止して手動確認を要求 |

作成したタグを削除・上書き・移動することはありません。検証中にタグが変わったり消えたりした場合は停止します。
参照のない注釈付きタグオブジェクトだけではバージョンは公開されません。再検証後の試行で必要な参照を作成できます。

公開済み Release の再確認には古い CI ログの保存を要求しません。
タグ、コミット済み文書、作成者、タイトル、ノート、不変性は引き続き検証します。

### 準備

ブランチ作成後に止まったら、`git log release/X.Y.Z`、文書の差分、
`gh pr list --head release/X.Y.Z` を確認し、同じブランチから不足する push や PR 作成を完了します。
`prepare` の再実行では既存ブランチを置換しません。

準備後に master の Unreleased に変更が追加されると、公開は停止します。
レビューする PR でその変更をリリース文書に含めるか、作成済みで検証済みのタグから公開を完了してください。

## リポジトリ設定

所有者がコマンドとは別に設定します。

- **Immutable releases**：公開前に有効化します。新しい公開に適用され、過去の Release には遡及しません。
- **master の保護**：PR と両必須ジョブを要求し、削除・force-push の保護を維持します。
  管理者がマージ規則を回避しても、スクリプトは対象コミットの CI 成功を独立に要求します。
- **タグ保護**：`v*` の作成・更新・削除を管理者に制限します。公開済みタグを別コミットに移動しないでください。
- **Actions**：既定トークンを読み取り専用とし、PR 承認を無効にします。ワークフローは `contents: read`、
  checkout の完全 SHA 固定、`persist-credentials: false` を指定します。
- **認証情報**：公開用トークンや署名用認証情報を Actions に保存しません。

ローカルスクリプトはアクセス制御の代わりにはならず、保護規則や権限も編集しません。
過去の軽量タグや可変 Release は履歴として残し、取り込み直したり書き換えたりしません。

## 開発時の検証

```sh
python3 -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh
```

一時 Git リポジトリと模擬 GitHub 応答で、両言語の文書更新、対象 CI の照合、拒否条件、タグ整合性、
中断・再実行、ページネーション、PR 作成を検証します。ネットワークや認証は不要です。

`release-tooling` ジョブは Ubuntu 24.04 で実行します。macOS ジョブは Swift ビルド・テスト、
iOS、フォーマット、RELEASE 診断監査、DocC、サンプルを検証します。
全コマンドは[貢献ガイド](../CONTRIBUTING.md)を参照してください。

## 参考資料

- [swift-app-macros PR #8 の所有者認証によるリリース設計](https://github.com/9uiLe/swift-app-macros/pull/8)
- [GitHub Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
- [GitHub Release API](https://docs.github.com/en/rest/releases/releases)
- [GitHub CLI による Release 作成](https://cli.github.com/manual/gh_release_create)
- [GitHub CLI の環境変数](https://cli.github.com/manual/gh_help_environment)
- [Ubuntu 24.04 ランナー](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
