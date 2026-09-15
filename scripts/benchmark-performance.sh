#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repository_root}"

source_directory="${SCOPED_ANIMATION_BENCHMARK_SOURCES:-Sources/ScopedAnimation}"
configuration="${1:-release}"
case "${configuration}" in
  release) flags=(-O) ;;
  debug) flags=(-Onone -D DEBUG) ;;
  *) echo 'Usage: bash scripts/benchmark-performance.sh [release|debug]' >&2; exit 2 ;;
esac

benchmark_dir="$(mktemp -d)"
trap 'rm -rf "${benchmark_dir}"' EXIT

xcrun swiftc -swift-version 6 -parse-as-library \
  -target "$(uname -m)-apple-macosx14.0" \
  "${flags[@]}" \
  "${source_directory}"/*.swift \
  "${source_directory}"/Diagnostics/*.swift \
  Benchmarks/ScopedAnimationBenchmarks.swift \
  -o "${benchmark_dir}/benchmark"
"${benchmark_dir}/benchmark"
