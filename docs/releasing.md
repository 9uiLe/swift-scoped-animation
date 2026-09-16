# リリースの設計と運用

ScopedAnimation は、`9uiLe/swift-scoped-animation` の Git タグからソースを配布する Swift パッケージです。
所有者 `9uiLe` が安定版のバージョンを選び、文書を PR で確定し、CI で検証したコミットをローカル認証で公開します。

## 成果物と責務

| 項目 | 契約 |
| --- | --- |
| バージョン | 数値の `X.Y.Z`。API 互換性に応じて所有者が選択 |
| Git タグ | ソースコミットを直接指す注釈付き `vX.Y.Z` |
| GitHub Release | タイトルは `X.Y.Z`、本文は CHANGELOG の該当バージョンの節、バイナリ添付なし |
| 公開後の保護 | GitHub の Immutable releases による固定。ツールはタグを移動・削除・置換しない |
| 準備と公開 | 所有者のローカル `scripts/release.py` と GitHub CLI 認証 |
| CI | 読み取り権限の GitHub Actions。公開用の認証情報は持たない |

**リモートタグの作成時点から、SwiftPM はそのバージョンを取得できます。**
公開条件をすべて確認してからタグを作ります。GitHub Release は下書きで作成し、タグとの整合性を確認して公開します。

コマンド引数と README には `v` なしの数値バージョンを指定します。
プレリリース、ビルドメタデータ、先頭ゼロ、引数の `v` 接頭辞は受け付けません。

## 前提条件

Python 3.10+、Git、現在の GitHub CLI を用意し、追跡・未追跡の変更がない作業ツリーで実行します。
所有者の認証を選択してください。

```sh
gh auth login --hostname github.com
gh auth switch --hostname github.com --user 9uiLe
```

ツールは API で実際の認証ユーザーを確認します。`GH_TOKEN` などの環境変数は保存済み CLI 認証より優先されます。
`origin` は上流の HTTPS URL または `git@github.com:9uiLe/swift-scoped-animation.git` を指定します。
fetch/push は GitHub CLI と同じ認証を使う HTTPS 経由のため、origin が SSH でも SSH 鍵は不要です。
GitHub Actions 内での実行は拒否します。

### GitHub の設定

所有者が次を設定します。ローカルスクリプトは権限や保護規則を編集しません。

- **Immutable releases**：公開前に有効化する。適用対象は有効化後の公開。
- **master の保護**：PR と `build-test-docs`・`Release tooling checks` の成功を要求し、削除・force-push を保護する。
- **タグ保護**：`v*` の作成・更新・削除を管理者に制限する。公開したタグの移動は禁止。
- **Actions**：既定トークンを読み取り専用にし、PR 承認を無効にする。
  ワークフローには `contents: read`、checkout の完全 SHA 固定、`persist-credentials: false` を指定する。
- **認証情報**：公開用トークンや署名用認証情報を Actions に保存しない。

アクセス制御は GitHub の設定が担い、ツールは公開対象の整合性を検証します。
管理者がマージ規則を回避した場合も、公開時には対象コミットの CI 成功を要求します。
軽量タグや可変 Release を、ツールが注釈付きタグや不変 Release に変換することはありません。

## コマンドの役割

`X.Y.Z` は選んだ安定版バージョンに置き換えます。

| コマンド | 動作 |
| --- | --- |
| `./scripts/release.py prepare X.Y.Z --dry-run` | ソースとタグを取得し、準備条件を確認して SHA とリリースノートを表示 |
| `./scripts/release.py prepare X.Y.Z` | `release/X.Y.Z` で文書を更新・push し、master 向け PR を作成 |
| `./scripts/release.py check X.Y.Z` | 公開条件を検証し、SHA・該当 CI の URL・ノートを表示 |
| `./scripts/release.py publish X.Y.Z` | 公開条件を再検証し、タグと下書きを作成または再開して、公開後の状態を確認 |

`prepare --dry-run` と `check` は取得済み参照を更新します。作業ファイル・作業ブランチ・リモート状態は変更しません。
`scripts/release.sh` は同じサブコマンドを Python に渡します。サブコマンドの指定は必須です。
準備と公開はそれぞれ独立した操作です。

## 1. リリース文書を準備する

`CHANGELOG.md` の `## Unreleased` に、利用者向けの変更を記録します。
破壊的変更には移行手順を含めます。ノートは GitHub Release に掲載するため、リンクには絶対 URL を使います。
解析用見出しは `## Unreleased` と `## X.Y.Z - YYYY-MM-DD`、本文と小見出しは日本語です。

```sh
./scripts/release.py prepare X.Y.Z --dry-run
./scripts/release.py prepare X.Y.Z
```

準備対象は、作業中のブランチによらず取得した `origin/master` です。

| 検証対象 | 条件 |
| --- | --- |
| 選択したバージョン | 認識できるすべての安定版タグと、CHANGELOG の最新バージョンより新しい |
| Unreleased | 先頭に 1 つだけ存在し、変更項目がある |
| リリース見出し | 正しい日付を持ち、バージョンが重複せず新しい順に並ぶ |
| README | `README.md` と `README.en.md` に導入宣言がそれぞれ 1 つあり、最新 CHANGELOG のバージョンと一致 |
| 作成先 | 対象タグ、Release、ローカル・リモートの `release/X.Y.Z` ブランチが存在しない |

準備コマンドは空の Unreleased と日付付きリリース節を作り、両 README の導入バージョンを更新します。
選んだソース SHA を親として 3 ファイルを同じコミットに収め、ブランチを push して PR を作成します。
変更対象はリリース文書です。バージョンの選択と PR のマージは所有者が行います。

## 2. 準備 PR をマージする

ノート、日付、両 README のバージョンを確認して master へマージします。
文書だけの更新も含め、master のすべての push が CI の対象です。

公開には、**対象ソース SHA の master push CI** が必要です。
最新の実行・再試行で、必須ジョブ `build-test-docs` と `Release tooling checks` の両方が成功している必要があります。
PR のチェック、手動実行、別コミットの結果は公開条件を満たしません。

失敗・キャンセル時は原因を解消して CI を再実行するか、修正 PR をマージします。
成功した再試行は公開条件を満たします。

## 3. ソースを検証して公開する

```sh
./scripts/release.py check X.Y.Z
./scripts/release.py publish X.Y.Z
```

`check` で公開するコミットとノートを確認します。`publish` は、その確認結果に依存せず条件を再検証します。

| 検証対象 | 条件 |
| --- | --- |
| アカウントと上流 | 認証ユーザーが `9uiLe`、公開リポジトリで master を使用し、管理者権限がある |
| 作業ツリー | 追跡・未追跡の変更がない |
| 成果物の保護 | Immutable releases が有効 |
| ソース | 取得した master の履歴に含まれる完全なコミット SHA |
| 文書 | 最新 CHANGELOG と両 README が対象バージョンに一致し、ノートと正しい日付があり、Unreleased が空 |
| CI 実行 | 有効な `ci.yml`、上流リポジトリ、push イベント、master、対象 SHA、最新の実行・再試行が一致 |
| CI ジョブ | 各必須ジョブが 1 つだけあり、成功し、ソース SHA も一致 |
| タグが存在する場合 | コミットを直接指す注釈付き `vX.Y.Z`。軽量タグ・入れ子のタグは拒否 |
| Release が存在する場合 | タグ・SHA・タイトル・所有者・ノートが一致し、プレリリースでも添付付きでもない。公開済みなら不変 |

新規タグの対象は取得した `origin/master` の先端です。作成直前にリモート master の一致を再確認します。
タグが存在する場合は、master が進んでいてもそのタグのコミットを使います。

未公開のバージョンは、他の安定版タグより新しい必要があります。
比較には `v` あり・なしのタグを含み、`0.3.0` と `v0.3.0` のような別名での重複を拒否します。

タグを作成後・Release 公開前・公開後に確認し、下書きも公開前に内容を照合します。
公開済みかつ不変な最終状態を確認すると、Release の URL を表示します。

## 中断からの再開

### 公開状態ごとの動作

原因を解消し、同じバージョンで `publish` を実行します。

| リモート状態 | 動作 |
| --- | --- |
| タグも Release もない | master の先端を検証し、タグ作成から開始 |
| 一致する注釈付きタグがある | タグのコミットと CI を検証し、下書きを作成 |
| 一致する下書きがある | タグ・ソース・内容・CI を検証して公開 |
| 一致する公開済みの不変な Release がある | ソースと内容を検証し、書き込みなしで URL を表示 |
| 不一致のタグまたは Release がある | 停止して手動確認を要求 |

公開済み Release の照合には古い CI ログの保存を要求しません。
タグ、コミット済み文書、作成者、タイトル、ノート、不変性を検証します。

検証中にタグが変わったり消えたりした場合は停止します。ツールはタグを削除・上書き・移動しません。
参照のない注釈付きタグオブジェクトだけではバージョンは公開されず、再検証後の試行で必要な参照を作成できます。

### 準備が中断した場合

ブランチ作成後の状態は、次で確認します。

```sh
git log release/X.Y.Z
git diff origin/master...release/X.Y.Z -- CHANGELOG.md README.md README.en.md
gh pr list --head release/X.Y.Z
```

文書の内容を確認し、同じブランチから不足する push や PR 作成を完了します。
`prepare` の再実行は、存在するブランチを置換しません。

準備後に master の Unreleased に変更が入ると、その master からの公開は停止します。
PR でリリース文書に含めるか、対象バージョンの検証済みタグがある場合はそのコミットから公開を完了します。

## リリースツールの検証

```sh
python3 -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh
```

テストは一時 Git リポジトリと模擬 GitHub 応答を使い、ネットワークや認証を必要としません。
両言語の文書更新、CI の照合、拒否条件、タグ整合性、中断・再実行、ページネーション、PR 作成を検証します。

`Release tooling checks` は Ubuntu 24.04 で実行します。
`build-test-docs` は macOS で Swift ビルド・macOS/iOS テスト・フォーマット・RELEASE 診断監査・DocC・サンプルを検証します。
開発時の全コマンドは[貢献ガイド](../CONTRIBUTING.md)を参照してください。

## 外部仕様

- [GitHub Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
- [GitHub Release API](https://docs.github.com/en/rest/releases/releases)
- [GitHub CLI による Release 作成](https://cli.github.com/manual/gh_release_create)
- [GitHub CLI の環境変数](https://cli.github.com/manual/gh_help_environment)
- [Ubuntu 24.04 ランナー](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
