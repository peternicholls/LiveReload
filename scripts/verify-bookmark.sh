#!/usr/bin/env bash
set -euo pipefail

FIXTURE="$(mktemp -d /tmp/livereload-bookmark.XXXXXX)"
trap 'rm -rf "$FIXTURE"' EXIT

swift - "$FIXTURE" <<'SWIFT'
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let bookmark = try folder.bookmarkData(
    options: [.withSecurityScope],
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)
var isStale = false
let resolved = try URL(
    resolvingBookmarkData: bookmark,
    options: [.withSecurityScope, .withoutUI],
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
guard !bookmark.isEmpty, resolved.standardizedFileURL == folder.standardizedFileURL, !isStale else {
    fatalError("bookmark round trip failed")
}
guard resolved.startAccessingSecurityScopedResource() else {
    fatalError("security-scoped access did not start")
}
resolved.stopAccessingSecurityScopedResource()
print("PASS: disposable security-scoped bookmark create/resolve/access/release")
SWIFT
