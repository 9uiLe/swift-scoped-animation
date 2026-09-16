#!/usr/bin/env bash

set -euo pipefail

debug_dump="$(mktemp)"
release_dump="$(mktemp)"
trap 'rm -f "${debug_dump}" "${release_dump}"' EXIT

collect_symbols() {
  local configuration="$1"
  local output="$2"
  local object_count

  object_count="$(find .build -type f -path "*/${configuration}/ScopedAnimation.build/*.o" | wc -l)"
  if [[ "${object_count}" -eq 0 ]]; then
    echo "${configuration} の ScopedAnimation オブジェクトファイルがありません" >&2
    exit 1
  fi

  find .build -type f -path "*/${configuration}/ScopedAnimation.build/*.o" -exec nm {} + \
    >"${output}"
  find .build -type f -path "*/${configuration}/ScopedAnimation.build/*.o" -exec strings {} + \
    >>"${output}"
}

collect_symbols debug "${debug_dump}"
collect_symbols release "${release_dump}"

markers=(
  AnimationLeakDetectorModifier
  AnimationScopeRuntimeWarning
  AnimationScopeWarning
  RuntimeWarningDebouncer
  AnimationScopeBoundaryPreferenceKey
  crossScopeAnimationStrip
  AnimationScopeDebugOverlayModifier
  com.apple.runtime-issues
  multiTriggerConflict
)

for marker in "${markers[@]}"; do
  if ! grep -q "${marker}" "${debug_dump}"; then
    echo "DEBUG の存在確認で診断マーカーが見つかりません: ${marker}" >&2
    exit 1
  fi

  if grep -q "${marker}" "${release_dump}"; then
    echo "RELEASE に診断マーカーが残っています: ${marker}" >&2
    exit 1
  fi
done

echo "検証完了: DEBUG のマーカーが存在し、RELEASE の診断は除去されています。"
