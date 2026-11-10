#!/usr/bin/env bash
#
# Build tibyan-<version>-<x86_64|aarch64>.AppImage (the build machine's arch) from a Flutter Linux release bundle.
#
#   linux/packaging/build-appimage.sh <bundle dir> <version> <out dir>
#
# Built on Ubuntu 22.04 (glibc 2.35) so it runs on that and anything newer.
# libmpv and its own dependencies are bundled (the recitation works without a
# system mpv); GTK, glibc and the graphics stack come from the system, as the
# AppImage excludelist that linuxdeploy applies expects.
#
# Needs: libmpv on the build machine, and network to fetch the two tools below
# (pinned by version and checked by sha256).
set -euo pipefail

BUNDLE="$(cd "$1" && pwd)"; VERSION="$2"; OUT="$(mkdir -p "$3" && cd "$3" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ICONS="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
# AI_ARCH names the AppImage tools; LDARCH is how ldconfig -p tags the libraries.
AI_ARCH="$(uname -m)"
case "$AI_ARCH" in
  x86_64)  LDARCH="x86-64" ;;
  aarch64) LDARCH="AArch64" ;;
  *) echo "unsupported architecture: $AI_ARCH"; exit 1 ;;
esac
NAME="tibyan-${VERSION}-${AI_ARCH}.AppImage"

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-${AI_ARCH}.AppImage"
LINUXDEPLOY_SHA="${LINUXDEPLOY_SHA:?set LINUXDEPLOY_SHA}"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-${AI_ARCH}.AppImage"
APPIMAGETOOL_SHA="${APPIMAGETOOL_SHA:?set APPIMAGETOOL_SHA}"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
fetch() { curl -fsSL --retry 3 -o "$WORK/$3" "$1"; echo "$2  $WORK/$3" | sha256sum -c -; chmod +x "$WORK/$3"; }
fetch "$LINUXDEPLOY_URL" "$LINUXDEPLOY_SHA" linuxdeploy
fetch "$APPIMAGETOOL_URL" "$APPIMAGETOOL_SHA" appimagetool
export APPIMAGE_EXTRACT_AND_RUN=1   # no FUSE in CI containers

LIBMPV="$(ldconfig -p | awk -v a="$LDARCH" '/libmpv\.so\.[12] / && index($0,a){print $NF; exit}')"
[ -n "$LIBMPV" ] || { echo "libmpv not found on the build machine"; exit 1; }

A="$WORK/AppDir"
mkdir -p "$A/usr/lib/tibyan" "$A/usr/bin" "$A/usr/share/applications"
cp -a "$BUNDLE/." "$A/usr/lib/tibyan/"
# Sentry crash reporting execs lib/crashpad_handler; older bundles shipped it 0644.
find "$A/usr/lib/tibyan" -name crashpad_handler -type f -exec chmod 755 {} +
ln -s ../lib/tibyan/tibyan "$A/usr/bin/tibyan"
cp "$HERE/app.tibyan.tibyan.desktop" "$A/usr/share/applications/"
for n in 16 32 64 128 256 512; do
  install -Dm644 "$ICONS/app_icon_$n.png" "$A/usr/share/icons/hicolor/${n}x${n}/apps/app.tibyan.tibyan.png"
done

# libmpv (dlopen()ed by media_kit, so name it explicitly) and the system
# libraries the bundle's plugins link to, each with its dependencies.
"$WORK/linuxdeploy" --appdir "$A" \
  --library "$LIBMPV" \
  --deploy-deps-only "$A/usr/lib/tibyan/lib" \
  --deploy-deps-only "$A/usr/lib/tibyan/tibyan" \
  --desktop-file "$A/usr/share/applications/app.tibyan.tibyan.desktop" \
  --icon-file "$ICONS/app_icon_256.png" --icon-filename app.tibyan.tibyan \
  --custom-apprun "$HERE/AppRun"

# GTK itself must come from the host (themes, input methods, its own modules);
# a bundled copy breaks on newer distributions.
find "$A/usr/lib" -maxdepth 1 \( -name 'libgtk-3.so*' -o -name 'libgdk-3.so*' \
  -o -name 'libgdk_pixbuf-2.0.so*' -o -name 'libgio-2.0.so*' -o -name 'libglib-2.0.so*' \
  -o -name 'libgobject-2.0.so*' -o -name 'libgmodule-2.0.so*' -o -name 'libpango*' \
  -o -name 'libcairo*' -o -name 'libatk*' -o -name 'libatspi*' \) -print -delete

# libmpv also links JACK and libusb, which the excludelist leaves to the host
# but many desktops lack; carry them (they work without a JACK server).
for l in libjack.so.0 libusb-1.0.so.0; do
  p="$(ldconfig -p | awk -v l="$l" -v a="$LDARCH" '$1==l && index($0,a){print $NF; exit}')"
  [ -n "$p" ] && cp -L "$p" "$A/usr/lib/$l"
done

ARCH="$AI_ARCH" "$WORK/appimagetool" --no-appstream "$A" "$OUT/$NAME"
ls -la "$OUT/$NAME"
