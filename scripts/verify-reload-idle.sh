#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$(mktemp -t livereload-idle-probe.XXXXXX)"
trap 'rm -f "$OUTPUT"' EXIT

swift run \
  --package-path "$ROOT/Packages/LiveReloadCore" \
  -c release \
  -Xswiftc -warnings-as-errors \
  LiveReloadIdleProbe 2>&1 | tee "$OUTPUT"

result="$(awk -F= '$1 == "result" { print $2; exit }' "$OUTPUT")"
sample_count="$(awk -F= '$1 ~ /^sample_[0-9]+_cpu_percent$/ { count++ } END { print count + 0 }' "$OUTPUT")"
declared_count="$(awk -F= '$1 == "sample_count" { print $2; exit }' "$OUTPUT")"
mean="$(awk -F= '$1 == "mean_cpu_percent" { print $2; exit }' "$OUTPUT")"
warmup="$(awk -F= '$1 == "warmup_seconds" { print $2; exit }' "$OUTPUT")"
interval="$(awk -F= '$1 == "sample_interval_seconds" { print $2; exit }' "$OUTPUT")"
cleanup_cycles="$(awk -F= '$1 == "cleanup_cycles" { print $2; exit }' "$OUTPUT")"
monitor_stops="$(awk -F= '$1 == "monitor_stops" { print $2; exit }' "$OUTPUT")"
access_releases="$(awk -F= '$1 == "scoped_access_releases" { print $2; exit }' "$OUTPUT")"
listener_rebinds="$(awk -F= '$1 == "listener_rebinds" { print $2; exit }' "$OUTPUT")"
session_releases="$(awk -F= '$1 == "ready_session_releases" { print $2; exit }' "$OUTPUT")"

[[ "$result" == "PASS" ]] || { printf 'FAIL: idle resource probe failed\n' >&2; exit 1; }
[[ "$warmup" == "30" && "$interval" == "1" ]] \
  || { printf 'FAIL: required warm-up or sample interval was not used\n' >&2; exit 1; }
[[ "$sample_count" == "300" && "$declared_count" == "300" ]] \
  || { printf 'FAIL: expected exactly 300 CPU samples\n' >&2; exit 1; }
[[ "$cleanup_cycles" == "3" && "$monitor_stops" == "4" \
   && "$access_releases" == "4" && "$listener_rebinds" == "4" \
   && "$session_releases" == "3" ]] \
  || { printf 'FAIL: monitor, folder, listener, or session cleanup was incomplete\n' >&2; exit 1; }
[[ -n "$mean" ]] || { printf 'FAIL: mean CPU was not recorded\n' >&2; exit 1; }
awk -v mean="$mean" 'BEGIN { exit !(mean + 0 < 1.0) }' \
  || { printf 'FAIL: mean CPU is not below 1%%\n' >&2; exit 1; }

printf 'PASS: 30-second warm-up, 300 one-second samples, and resource cleanup gate\n'
