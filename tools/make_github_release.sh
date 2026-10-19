#!/usr/bin/env bash
# Build the GitHub release assets on this Mac and (only with --publish) create the release.
#
#   tools/make_github_release.sh <build-number> [--tag vX.Y.Z] [--notes FILE] [--skip-build] [--publish]
#
# Default is a dry run: it builds, checksums and prints the `gh release create`
# command without running it. Nothing is uploaded without --publish.
#
# Assets (in build/github-release/<tag>/):
#   tibyan-<ver>-android-arm64-v8a.apk, -armeabi-v7a.apk, -x86_64.apk   (split per ABI)
#   tibyan-<ver>-android-universal.apk
#   tibyan-<ver>-macos.zip    (Developer ID signed + notarized when credentials exist, otherwise unsigned)
#   SHA256SUMS
#
# Android signing uses android/key.properties (git-ignored, never committed). Without it the
# script stops: a debug-signed APK cannot update the Play build.
# macOS notarization needs, in the environment:
#   TIBYAN_DEVELOPER_ID   e.g. "Developer ID Application: Name (TEAMID)"
#   TIBYAN_NOTARY_PROFILE a notarytool keychain profile (xcrun notarytool store-credentials)
# iOS is not distributed on GitHub: TestFlight https://testflight.apple.com/join/gxJ4rrdd
#
# Note: pushing a v* tag also runs .github/workflows/release.yml, which builds every platform
# and attaches its files to the release with the same tag (and sets the body from CHANGELOG.md).
set -euo pipefail

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

BUILD=""; TAG=""; NOTES=""; PUBLISH=0; SKIP_BUILD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --tag) TAG="$2"; shift ;;
    --notes) NOTES="$2"; shift ;;
    -h|--help) usage 0 ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) [ -z "$BUILD" ] || usage; BUILD="$1" ;;
  esac
  shift
done
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "Give the build number (an integer above the last Play/TestFlight build)." >&2; usage; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VER="$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' pubspec.yaml)"
[ -n "$VER" ] || { echo "No version in pubspec.yaml" >&2; exit 1; }
TAG="${TAG:-v$VER}"
if [ "${TAG#v}" != "$VER" ]; then
  echo "Tag $TAG does not match pubspec version $VER. Run: python3 tools/release/prepare.py ${TAG#v}" >&2
  exit 1
fi
NOTES="${NOTES:-docs/release-notes/$TAG.md}"
[ -s "$NOTES" ] || { echo "Release notes not found: $NOTES" >&2; exit 1; }

OUT="build/github-release/$TAG"
NAME="tibyan-$VER"

for t in flutter gh shasum ditto; do command -v "$t" >/dev/null || { echo "Missing tool: $t" >&2; exit 1; }; done
[ -f android/key.properties ] || { echo "android/key.properties is missing: copy it from ~/.config/tibyan/ (never commit it)." >&2; exit 1; }
if gh release view "$TAG" >/dev/null 2>&1; then echo "Note: release $TAG already exists on GitHub." >&2; fi

echo "== $TAG (build $BUILD) -> $OUT"

if [ "$SKIP_BUILD" -eq 0 ]; then
  rm -rf "$OUT"; mkdir -p "$OUT"
  flutter pub get

  # Android: per-ABI APKs, then the universal one (the second build replaces the first's outputs).
  flutter build apk --release --split-per-abi --build-number="$BUILD"
  for abi in arm64-v8a armeabi-v7a x86_64; do
    cp "build/app/outputs/flutter-apk/app-$abi-release.apk" "$OUT/$NAME-android-$abi.apk"
  done
  flutter build apk --release --build-number="$BUILD"
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/$NAME-android-universal.apk"

  # Check the APK is signed with the upload key, not the debug key.
  APKSIGNER="$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)"
  if [ -n "$APKSIGNER" ]; then
    if "$APKSIGNER" verify --print-certs "$OUT/$NAME-android-universal.apk" | grep -q "CN=Android Debug"; then
      echo "The APK is debug-signed: check android/key.properties." >&2; exit 1
    fi
  fi

  # macOS
  flutter build macos --release --build-number="$BUILD"
  APP="$(ls -d build/macos/Build/Products/Release/*.app | head -1)"
  MAC_STATE="unsigned"
  if [ -n "${TIBYAN_DEVELOPER_ID:-}" ] && [ -n "${TIBYAN_NOTARY_PROFILE:-}" ]; then
    codesign --force --deep --options runtime --timestamp --sign "$TIBYAN_DEVELOPER_ID" "$APP"
    ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
    xcrun notarytool submit "$OUT/notarize.zip" --keychain-profile "$TIBYAN_NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm "$OUT/notarize.zip"
    MAC_STATE="signed and notarized"
  fi
  ditto -c -k --keepParent "$APP" "$OUT/$NAME-macos.zip"
  echo "$MAC_STATE" > "$OUT/.macos-state"
fi

[ -d "$OUT" ] || { echo "No build in $OUT (drop --skip-build)." >&2; exit 1; }
MAC_STATE="$(cat "$OUT/.macos-state" 2>/dev/null || echo unsigned)"

( cd "$OUT" && rm -f SHA256SUMS && shasum -a 256 ./*.apk ./*.zip | sed 's| \./| |' > SHA256SUMS && cat SHA256SUMS )

# Release notes plus the macOS signing state.
FINAL_NOTES="$OUT/notes.md"
cp "$NOTES" "$FINAL_NOTES"
if [ "$MAC_STATE" = "unsigned" ]; then
  printf '\n> **macOS:** unsigned — right-click the app → Open the first time. / غير موقّع: انقر بالزر الأيمن ← فتح في أول مرة.\n' >> "$FINAL_NOTES"
fi

ASSETS=("$OUT"/*.apk "$OUT"/*.zip "$OUT/SHA256SUMS")
CMD=(gh release create "$TAG" --title "Tibyan ${TAG#v} | تبيان ${TAG#v}" --notes-file "$FINAL_NOTES" --prerelease "${ASSETS[@]}")

echo
echo "macOS build: $MAC_STATE"
if [ "$PUBLISH" -eq 1 ]; then
  "${CMD[@]}"
else
  echo "Dry run. With --publish this would run:"
  printf '  %q' "${CMD[@]}"; echo
fi
