#!/bin/zsh
set -euo pipefail

ROOT="${1:?usage: sleep-wake-capture.sh WATCH_DIRECTORY EVIDENCE_FILE}"
EVIDENCE="${2:?usage: sleep-wake-capture.sh WATCH_DIRECTORY EVIDENCE_FILE}"
PROTOTYPE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$(dirname "$EVIDENCE")"
swift build -Xswiftc -warnings-as-errors --package-path "$PROTOTYPE_DIR"
"$PROTOTYPE_DIR/.build/debug/FSEventsPrototype" watch "$ROOT" 120 > "$EVIDENCE" 2>&1 &
PID=$!

print "FSEvents monitor started (PID $PID)."
print "1. Put this Mac to sleep normally."
print "2. Wake and unlock it."
print "3. Create or edit a file inside: $ROOT"
print "4. Wait for this script to exit, then inspect: $EVIDENCE"

wait "$PID"
grep -q 'EVENT ' "$EVIDENCE"
grep -q 'STOPPED ' "$EVIDENCE"
print "PASS: sleep/wake monitor capture contains event and clean stop."
