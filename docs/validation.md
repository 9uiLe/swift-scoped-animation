# 検証記録

- 記録日：**2026-09-16**
- ツールチェーン：Xcode 26.5 (17F42)、Apple Swift 6.3.2、Swift 6 言語モード
- ホスト：Apple M1 Pro、macOS 26.2 (25C56)
- シミュレーター：iPhone 17、iOS 26.5、UDID `5A6604DB-0328-4DFD-89EF-6A5EEE0CE974`

以下はライブラリ検証を実行した記録です。ソースは未コミットの作業ツリーであり、
特定のリリースやコミットを認証する結果ではありません。検証範囲は記載した環境に限定されます。
完全なローカルログは `/tmp/scoped-animation-performance-20260916/` に保存し、抜粋をここに残しています。
コマンドと出力は実行時の原文です。

## 検証範囲

ホストテストは、外からの除去、プロキシのスタンプ経路、値駆動の所有者、入れ子、複数トリガーの優先順位、
要素数変更、無効化、連続更新、トランジション、診断配置を検証します。
純粋なテストは具象型、選択、スタンプの同一性、上限付きデバウンスを検証します。

カスタムアニメーションの description 観測で、抑制された警告が文字列化しないことを確認します。
RELEASE テストとバイナリのマーカー監査で、本番成果物から診断実装が除去されることを確認します。

フレームワークの契約は [SwiftUI の前提](swiftui-assumptions.md)、現行の検証コマンドは
[貢献ガイド](../CONTRIBUTING.md)を参照してください。

## macOS DEBUG

```sh
swift build
swift test
```

実出力の抜粋：

```text
Build complete! (0.19s)
􁁛  Test run with 55 tests in 12 suites passed after 28.894 seconds.
```

## iOS シミュレーター

```sh
xcodebuild test -scheme ScopedAnimation \
  -destination 'platform=iOS Simulator,id=5A6604DB-0328-4DFD-89EF-6A5EEE0CE974' \
  -derivedDataPath /tmp/scoped-animation-refactor-dd COMPILER_INDEX_STORE_ENABLE=NO
```

実出力の抜粋：

```text
✔ Test run with 55 tests in 12 suites passed after 29.966 seconds.
** TEST SUCCEEDED **
```

## macOS RELEASE と診断監査

```sh
swift build -c release
swift test -c release
bash scripts/verify-release-diagnostics.sh
```

実出力の抜粋：

```text
Build complete! (1.02s)
􁁛  Test run with 38 tests in 9 suites passed after 21.368 seconds.
Verified: DEBUG markers are present and RELEASE diagnostics are absent.
```

## 文書・サンプル・静的検査

```sh
xcodebuild docbuild -scheme ScopedAnimation -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/scoped-animation-docs-dd COMPILER_INDEX_STORE_ENABLE=NO
xcodebuild build \
  -project Examples/ScopedAnimationExample/ScopedAnimationExample.xcodeproj \
  -scheme ScopedAnimationExample \
  -destination 'platform=iOS Simulator,id=5A6604DB-0328-4DFD-89EF-6A5EEE0CE974' \
  -derivedDataPath /tmp/scoped-animation-example-dd COMPILER_INDEX_STORE_ENABLE=NO
swift format lint --strict --recursive Sources Tests Benchmarks \
  Examples/ScopedAnimationExample/ScopedAnimationExample Package.swift
bash -n scripts/benchmark-performance.sh scripts/verify-release-diagnostics.sh scripts/release.sh
git diff --check
```

Xcode の実出力の抜粋：

```text
** BUILD DOCUMENTATION SUCCEEDED **
** BUILD SUCCEEDED **
```

フォーマット、シェル構文、空白検査は出力なしで終了コード 0 でした。Swift コンパイラの警告はありませんでした。
Xcode の App Intents 処理は、テストランナーとサンプルに対して
“Metadata extraction skipped. No AppIntents.framework dependency found.” を出力しました。
DocC は警告なしで完了しました。

## 未検証の範囲

- このソース状態の手動 QA は記録していません。[サンプル QA](../Examples/QA.md)の日付付き観測は、その実行環境に適用されます。
- テストは渡されたトランザクションを調べるもので、中間の描画フレームを検証しません。
- iOS・tvOS・watchOS・visionOS 実機は検証していません。
- フレームレート、アロケーション、消費電力の計測は対象外です。
