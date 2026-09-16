# 性能モデルと参考計測

ScopedAnimation の CPU 処理は、トリガー生成、値比較、トランザクション境界、DEBUG 診断から構成されます。
ここではコストモデルと内部マイクロベンチマークの参考値を記録します。

アプリの計測は[性能ガイド](../Sources/ScopedAnimation/Documentation.docc/PerformancePlaybook.md)、
正確なデータと手順は[ベンチマーク手順](../Benchmarks/README.md)を参照してください。

## コストモデル

| 操作 | 処理 |
| --- | --- |
| トリガー生成 | アニメーションを保存し、値を型消去し、必要な配列・クロージャ領域を確保 |
| スナップショット比較 | 位置ごとに具象型と値を比較。アニメーション設定は等価比較に含めない |
| 履歴解決 | 1 回の比較で変更なし・要素数変更・値変更を判定し、保留中の結果を保持 |
| RELEASE の選択 | 最初の変更済みトリガーで停止 |
| DEBUG の選択 | 最初の変更と、優先度が低い他の変更も収集 |
| 境界 | アニメーションを除去し、スタンプを保持。有効で ID が一致するスコープだけ復元 |
| 抑制された警告 | 箇所キーを作り、状態のロックを取り、上限付きデバウンス記憶領域を照会 |
| 受理した警告 | 型付きイベントを渡し、出力先が読むときにメッセージを整形 |
| DEBUG オーバーレイ | アンカーを集め、表示する境界を解決 |

SwiftUI の値ゲートも、履歴とは別にスナップショットを比較します。
プロキシスコープのスナップショットは空、単独バリアに履歴はありません。
診断と不採用トリガーの記憶領域は RELEASE には存在しません。

等価比較の複雑さは値の型に依存します。大きな配列や集合が管理処理の大半を占めることがあります。
条件を完全に表せるならスカラーや小さな値を使います。
更新カウンターは、すべての関連変更で確実に進められる場合だけ適します。

## 参考環境

- 日付：2026-09-16
- ハードウェア：Apple M1 Pro
- OS：macOS 26.2 (25C56)
- Xcode：26.5 (17F42)
- Swift：Apple Swift 6.3.2、Swift 6 言語モード
- 対象：macOS 14
- RELEASE 設定：`-O`
- DEBUG 設定：`-Onone -D DEBUG`

内部インターフェースを使うため、スクリプトはライブラリとベンチマークを同じモジュールでコンパイルします。
パッケージの製品や依存は追加しません。一時実行ファイルは実行後に削除します。

100 操作のウォームアップ後、7 バッチを測定します。スカラーと生成は 20,000 操作、
コレクションと診断は 2,000 操作です。未使用コードとしての除去を防ぐためチェックサムを使います。
診断ケースは各箇所で受理された警告が厳密に 1 回であることを確認し、計測する反復を抑制期間内に保ちます。

## CPU 時間の計測値

単位は **1 操作あたりのマイクロ秒**、値は 7 バッチの中央値です。
`changed=-1` は変更なし、それ以外の数値は変更した配列位置です。データの定義はベンチマーク手順を参照してください。

| ビルド | ケース | 中央値 (µs) |
| --- | --- | ---: |
| RELEASE | `history/count=1/changed=-1` | 0.089 |
| RELEASE | `history/count=1/changed=0` | 0.257 |
| RELEASE | `history/count=2/changed=-1` | 0.170 |
| RELEASE | `history/count=2/changed=0` | 0.226 |
| RELEASE | `history/count=2/changed=1` | 0.308 |
| RELEASE | `history/count=8/changed=-1` | 0.585 |
| RELEASE | `history/count=8/changed=0` | 0.225 |
| RELEASE | `history/count=8/changed=7` | 0.711 |
| RELEASE | `history/count=64/changed=-1` | 4.560 |
| RELEASE | `history/count=64/changed=0` | 0.224 |
| RELEASE | `history/count=64/changed=63` | 4.712 |
| RELEASE | `history/8x1024-element-arrays/changed=7` | 86.735 |
| RELEASE | `construct-and-compare/two-8-trigger-snapshots` | 4.329 |
| DEBUG | `history/count=1/changed=-1` | 0.839 |
| DEBUG | `history/count=1/changed=0` | 1.090 |
| DEBUG | `history/count=2/changed=-1` | 1.150 |
| DEBUG | `history/count=2/changed=0` | 1.406 |
| DEBUG | `history/count=2/changed=1` | 1.401 |
| DEBUG | `history/count=8/changed=-1` | 2.993 |
| DEBUG | `history/count=8/changed=0` | 3.274 |
| DEBUG | `history/count=8/changed=7` | 3.244 |
| DEBUG | `history/count=64/changed=-1` | 20.182 |
| DEBUG | `history/count=64/changed=0` | 20.554 |
| DEBUG | `history/count=64/changed=63` | 20.500 |
| DEBUG | `history/8x1024-element-arrays/changed=7` | 89.266 |
| DEBUG | `construct-and-compare/two-8-trigger-snapshots` | 8.991 |
| DEBUG | `suppressed-conflict/sites=1` | 0.860 |
| DEBUG | `suppressed-conflict/sites=64` | 1.633 |

この RELEASE 計測では、2 個のスカラートリガーの 2 個目が変わる履歴解決は約 0.31 µs、
8 配列のケースは約 87 µs です。値比較の複雑さの影響を示すもので、SwiftUI 更新全体の時間ではありません。

生データには最小値・中央値・最大値・反復数・チェックサムを含みます。

- [RELEASE CSV](benchmarks/2026-09-16-release.csv)
- [DEBUG CSV](benchmarks/2026-09-16-debug.csv)

## 再現手順

リポジトリのルートで実行します。

```sh
bash scripts/benchmark-performance.sh release
bash scripts/benchmark-performance.sh debug
```

ビルド、シミュレーターなど CPU 負荷の高い作業を同時に実行せず、構成ごとに順番に測ります。
環境と生出力を記録してください。スケジューリング、ハードウェア、コンパイラの違いは小さな差に影響します。
マイクロベンチマークの時間しきい値を CI の合否判定には使いません。

## 計測の範囲

次の処理は計測しません。

- SwiftUI の body 評価、値ゲート自身のスナップショット比較
- トランザクション伝播、レイアウト、描画、フレームのスケジューリング
- アロケーション数とピークメモリ
- オーバーレイのレイアウトと描画
- アプリのフレームレートと実機の消費電力

生成ケースはアロケーションと型消去にかかる時間を含みますが、回数は数えません。
診断ケースはコンソール I/O の代わりに専用の出力先を使います。いずれもアプリ全体のコストを示しません。

スコープは状態依存を切らず、body の無効化も防ぎません。対象サブツリーを小さくし、高価な派生値を避け、
代表的な操作を対象デバイスで計測してください。

## 性能上の不変条件と検証

意味論のテストで、繰り返す評価が保留中の選択結果を保持し、要素数変更で結果を消して基準を再設定し、
無関係な更新を動かさないことを確認します。診断テストは description の読み出しを観測できる
カスタムアニメーションで、受理した警告だけがメッセージを整形することを確認します。

[検証記録](validation.md)には macOS/iOS の振る舞い、RELEASE テスト、診断シンボル・文字列の監査を記載しています。
