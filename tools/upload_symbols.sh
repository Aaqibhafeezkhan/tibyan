#!/usr/bin/env bash
# Upload a release build's debug symbols to our GlitchTip (errors.altibyan.app), so
# crash reports show readable Dart and native stack traces.
#
#   tools/upload_symbols.sh <build-number>
#
# Run after a release build made with --split-debug-info=build/symbols/<build-number>
# (every release command in handoff/00-README «Releases» does this). It uploads what exists:
#   - Dart symbols:        build/symbols/<build>/
#   - iOS/macOS dSYMs:     the Xcode archive(s) in ~/Library/Developer/Xcode/Archives (newest
#                          Runner archive with this build number) and build/{ios,macos}/**.dSYM
#   - Android:             native libs (build/app/intermediates/merged_native_libs) and the
#                          R8 mapping if present
# dSYMs are also copied to ~/.config/tibyan/dsyms/<build>/ (kept, never committed).
#
# Needs sentry-cli (brew install getsentry/tools/sentry-cli) and ~/.config/tibyan/glitchtip.env
# with SENTRY_URL, SENTRY_ORG, SENTRY_PROJECT, SENTRY_AUTH_TOKEN (chmod 600, never committed).
set -euo pipefail

BUILD="${1:-}"
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "Usage: $0 <build-number>" >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$HOME/.config/tibyan/glitchtip.env"
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a
export SENTRY_URL SENTRY_ORG SENTRY_PROJECT SENTRY_AUTH_TOKEN
command -v sentry-cli >/dev/null || { echo "Install sentry-cli: brew install getsentry/tools/sentry-cli" >&2; exit 1; }

up() { echo "== upload: $*"; sentry-cli debug-files upload --include-sources "$@"; }

# Dart (split debug info)
if [ -d "build/symbols/$BUILD" ]; then
  up "build/symbols/$BUILD"
else
  echo "No Dart symbols in build/symbols/$BUILD (build with --split-debug-info=build/symbols/$BUILD)." >&2
fi

# iOS/macOS dSYMs: keep a copy, then upload.
KEEP="$HOME/.config/tibyan/dsyms/$BUILD"
mkdir -p "$KEEP"; chmod 700 "$HOME/.config/tibyan/dsyms" "$KEEP"
FOUND=0
while IFS= read -r -d '' plist; do
  arch="$(dirname "$plist")"
  v="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$plist" 2>/dev/null || true)"
  [ "$v" = "$BUILD" ] || continue
  if [ -d "$arch/dSYMs" ]; then
    name="$(basename "$arch" .xcarchive)"
    rsync -a "$arch/dSYMs/" "$KEEP/$name/"
    FOUND=1
  fi
done < <(find "$HOME/Library/Developer/Xcode/Archives" -name Info.plist -path '*.xcarchive/Info.plist' -mtime -14 -print0 2>/dev/null)
for d in build/ios build/macos; do
  [ -d "$d" ] || continue
  while IFS= read -r -d '' s; do rsync -a "$s" "$KEEP/$(basename "$d")/"; FOUND=1; done \
    < <(find "$d" -name '*.dSYM' -type d -prune -print0)
done
if [ "$FOUND" -eq 1 ]; then up "$KEEP"; else echo "No dSYMs found for build $BUILD." >&2; fi

# Android native libraries (Flutter engine + plugins) and the R8 mapping.
for d in build/app/intermediates/merged_native_libs/release build/app/outputs/native-debug-symbols/release; do
  [ -d "$d" ] && up "$d"
done
# R8 mapping: the Sentry Gradle plugin (android/app/build.gradle.kts) embeds its UUID in the
# APK/AAB and uploads it during the build when SENTRY_AUTH_TOKEN is set. Re-upload here as
# well, tagged with the same UUID, so a build made without the token can still be fixed up.
MAP=build/app/outputs/mapping/release/mapping.txt
if [ -f "$MAP" ]; then
  echo "== upload: proguard mapping"
  UUID_FILE=build/app/intermediates/assets/release/injectSentryDebugMetaPropertiesIntoAssetsRelease/sentry-debug-meta.properties
  UUID=""
  [ -f "$UUID_FILE" ] && UUID="$(sed -n 's/^io\.sentry\.ProguardUuids=//p' "$UUID_FILE")"
  if [ -n "$UUID" ]; then
    echo "   uuid $UUID (from the build)"
    sentry-cli upload-proguard --uuid "$UUID" "$MAP"
  else
    echo "No embedded ProGuard UUID found; uploading with a content UUID the app will not report." >&2
    sentry-cli proguard upload "$MAP"
  fi
fi
echo "Done: build $BUILD. dSYM copies in $KEEP"
