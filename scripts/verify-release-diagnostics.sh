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
    echo "No ${configuration} ScopedAnimation object files found" >&2
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
  AnimationScopeDebugOverlayModifier
  com.apple.runtime-issues
  multiTriggerConflict
)

for marker in "${markers[@]}"; do
  if ! grep -q "${marker}" "${debug_dump}"; then
    echo "DEBUG positive control is missing diagnostic marker: ${marker}" >&2
    exit 1
  fi

  if grep -q "${marker}" "${release_dump}"; then
    echo "RELEASE build contains diagnostic marker: ${marker}" >&2
    exit 1
  fi
done

echo "Verified: DEBUG markers are present and RELEASE diagnostics are absent."
