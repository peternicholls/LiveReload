#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/ModernLiveReload/LiveReload.xcodeproj"
SCHEME="LiveReload"
BUILD_ROOT="$ROOT/ModernLiveReload/Build"
APP="$BUILD_ROOT/Products/Release/LiveReloadApp.app"
DESTINATION="platform=macOS,arch=arm64"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }
run_with_timeout() {
  local limit="$1" elapsed=0 pid
  shift
  "$@" & pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= limit )); then
      kill -TERM "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 2
    ((elapsed += 2))
  done
  wait "$pid"
}

[[ -d "$PROJECT" ]] || fail "modern Xcode project is missing"
[[ -f "$ROOT/ModernLiveReload/LiveReload.xctestplan" ]] || fail "stable test plan is missing"

if rg -n '^import (SwiftUI|AppKit)$' "$ROOT/Packages/LiveReloadCore/Sources" "$ROOT/Packages/LiveReloadCore/Tests"; then
  fail "LiveReloadCore imports a UI framework"
fi
pass "LiveReloadCore UI boundary"

if rg -n '(https?://|\.package\s*\(url:|CocoaPods|node_modules|CoffeeScript|\bRuby\b|\bNode\.js\b)' \
  "$ROOT/Packages/LiveReloadCore/Package.swift" "$ROOT/ModernLiveReload/LiveReload.xcodeproj/project.pbxproj"; then
  fail "prohibited runtime or third-party dependency found in modern manifests"
fi
swift package --package-path "$ROOT/Packages/LiveReloadCore" show-dependencies --format json >/tmp/livereload-dependencies.json
[[ "$(plutil -extract dependencies raw -o - /tmp/livereload-dependencies.json)" == "0" ]] || fail "external Swift package dependency found"
pass "dependency inventory"

swift test --package-path "$ROOT/Packages/LiveReloadCore" -Xswiftc -warnings-as-errors
swift build --package-path "$ROOT/Packages/LiveReloadCore" -c release -Xswiftc -warnings-as-errors
pass "core Debug tests and Release build"
"$ROOT/scripts/verify-bookmark.sh"
pass "workspace-backed security-scoped bookmark adapter boundary"

IDENTITY_LINE="$(security find-identity -v -p codesigning | rg 'Apple Development:' | head -1 || true)"
[[ -n "$IDENTITY_LINE" ]] || fail "Apple Development signing identity is required"
CERT_PEM="$(security find-certificate -c 'Apple Development' -p)"
[[ -n "$CERT_PEM" ]] || fail "could not read signing certificate"
TEAM_ID="$(openssl x509 -noout -subject <<<"$CERT_PEM" | sed -E 's/.*OU=([^,]+).*/\1/')"
[[ -n "$TEAM_ID" ]] || fail "could not determine signing team"

SIGNING=(CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$TEAM_ID")
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -destination "$DESTINATION" build "${SIGNING[@]}"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -destination "$DESTINATION" build "${SIGNING[@]}"
DevToolsSecurity -status 2>&1 | rg -q 'enabled' \
  || fail "macOS developer mode is disabled; run 'sudo DevToolsSecurity -enable' before UI tests"
run_with_timeout 120 xcodebuild -project "$PROJECT" -scheme "$SCHEME" -testPlan LiveReload -configuration Debug -destination "$DESTINATION" test "${SIGNING[@]}" \
  || fail "app/UI test execution failed or exceeded 120 seconds"
pass "app Debug/Release and app/UI tests"

[[ -d "$APP" ]] || fail "Release app product is missing"
file "$APP/Contents/MacOS/LiveReloadApp" | rg -q 'arm64' || fail "Release app is not arm64"
SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings)"
rg -q 'ARCHS = arm64' <<<"$SETTINGS" || fail "ARCHS is not arm64"
rg -q 'MACOSX_DEPLOYMENT_TARGET = 15\.0' <<<"$SETTINGS" || fail "deployment floor is not macOS 15"
codesign --verify --deep --strict "$APP"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP" 2>&1)"
rg -q 'flags=.*runtime' <<<"$SIGNATURE_DETAILS" || fail "Hardened Runtime signature is missing"
pass "arm64, macOS 15 deployment, and Hardened Runtime signing"

VERSION="$(sed -n 's/^MARKETING_VERSION = //p' "$ROOT/ModernLiveReload/Version.xcconfig")"
BUILD="$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' "$ROOT/ModernLiveReload/Version.xcconfig")"
[[ -n "$VERSION" && -n "$BUILD" ]] || fail "single version source is incomplete"
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")" == "$VERSION" ]] || fail "bundle marketing version differs"
[[ "$(plutil -extract CFBundleVersion raw -o - "$APP/Contents/Info.plist")" == "$BUILD" ]] || fail "bundle build version differs"
for required in VERSIONING.md CHANGELOG.md NOTICE.md docs/project-ledger/software-inclusions.md docs/guides/user-guide.md docs/guides/developer-guide.md; do
  [[ -s "$ROOT/$required" ]] || fail "required documentation missing: $required"
done
rg -q '^## (\[Unreleased\]|Unreleased)$' "$ROOT/CHANGELOG.md" || fail "Unreleased changelog section missing"
pass "version, changelog, inclusion, NOTICE, and guides"

if git -C "$ROOT" ls-files | rg '(^|/)(\.build|DerivedData)/|^ModernLiveReload/Build/|\.(app|xcarchive|o|swiftmodule)$'; then
  fail "committed build product found"
fi
pass "tracked build-product privacy gate"

printf 'Modern verification completed successfully.\n'
