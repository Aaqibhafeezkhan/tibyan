#!/usr/bin/env bash
#
# Build tibyan_<version>-<build>_amd64.deb from a Flutter Linux release bundle.
#
#   linux/packaging/build-deb.sh <bundle dir> <version> <build> <out dir>
#
# Runs on Debian/Ubuntu with dpkg-dev (dpkg-shlibdeps). Layout:
#   /opt/tibyan/                        the Flutter bundle (tibyan, lib/, data/)
#   /usr/bin/tibyan -> /opt/tibyan/tibyan
#   /usr/share/applications/app.tibyan.tibyan.desktop
#   /usr/share/icons/hicolor/<n>x<n>/apps/app.tibyan.tibyan.png
#
# Depends = what dpkg-shlibdeps finds in the ELF files, plus the libraries the
# app opens at run time with dlopen (ldd cannot see them): libmpv for the
# recitation (media_kit tries libmpv.so.2, then .so.1).
set -euo pipefail

BUNDLE="$(cd "$1" && pwd)"; VERSION="$2"; BUILD="$3"; OUT="$4"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ICONS="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
DEB_VERSION="${VERSION}-${BUILD}"
PKG="tibyan_${DEB_VERSION}_amd64"

[ -x "$BUNDLE/tibyan" ] || { echo "no tibyan executable in $BUNDLE"; exit 1; }
mkdir -p "$OUT"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
D="$WORK/$PKG"

mkdir -p "$D/opt/tibyan" "$D/usr/bin" "$D/usr/share/applications" "$D/DEBIAN" \
  "$D/usr/share/doc/tibyan"
cp -a "$BUNDLE/." "$D/opt/tibyan/"
ln -s /opt/tibyan/tibyan "$D/usr/bin/tibyan"
install -m644 "$HERE/app.tibyan.tibyan.desktop" "$D/usr/share/applications/"
for n in 16 32 64 128 256 512; do
  install -Dm644 "$ICONS/app_icon_$n.png" \
    "$D/usr/share/icons/hicolor/${n}x${n}/apps/app.tibyan.tibyan.png"
done
install -m644 "$ROOT/LICENSE" "$D/usr/share/doc/tibyan/copyright"

# Shared-library dependencies of every ELF file in the bundle. The bundle's own
# lib/ is private (-l) so its libraries are not looked up in the system.
mkdir -p "$WORK/shl/debian"
printf 'Source: tibyan\n\nPackage: tibyan\nArchitecture: amd64\n' > "$WORK/shl/debian/control"
mapfile -t ELFS < <(find "$D/opt/tibyan" -type f \( -name '*.so*' -o -name tibyan \) \
  -exec sh -c 'head -c4 "$1" | grep -q ELF && echo "$1"' _ {} \;)
SHLIBS="$(cd "$WORK/shl" && dpkg-shlibdeps -O -l"$D/opt/tibyan/lib" \
  --ignore-missing-info "${ELFS[@]}" 2>"$WORK/shlibdeps.log" \
  | sed -n 's/^shlibs:Depends=//p')"
grep -v 'no dependency information found' "$WORK/shlibdeps.log" >&2 || true
[ -n "$SHLIBS" ] || { echo "dpkg-shlibdeps found nothing"; exit 1; }

# dlopen()ed at run time, so not in the ELF headers (libmpv by media_kit,
# EGL/GLESv2 by the Flutter engine). libcurl4t64 is the
# Ubuntu 24.04 name; libsecret/gtk are usually in SHLIBS already (harmless twice).
EXTRA="libmpv2 | libmpv1, libegl1, libgles2, libgtk-3-0 | libgtk-3-0t64, libsecret-1-0, libcurl4 | libcurl4t64"
SIZE_KB="$(du -sk --exclude=DEBIAN "$D" | cut -f1)"

cat > "$D/DEBIAN/control" <<EOF
Package: tibyan
Version: $DEB_VERSION
Architecture: amd64
Maintainer: Tibyan <info@altibyan.app>
Installed-Size: $SIZE_KB
Depends: $SHLIBS, $EXTRA
Section: education
Priority: optional
Homepage: https://altibyan.app
Description: Ad-free Quran app: recitation, tafsir and offline reading
 Tibyan (تبيان) is a free, non-profit Quran app: Madina mushaf pages,
 recitation by many reciters, tafsir, memorization and oral testing,
 all without ads and usable offline.
EOF

# Refresh the icon cache and menus when the tools are there (they usually are).
cat > "$D/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
  command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications || true
fi
exit 0
EOF
cp "$D/DEBIAN/postinst" "$D/DEBIAN/postrm"
sed -i 's/= configure/= remove/' "$D/DEBIAN/postrm"
chmod 755 "$D/DEBIAN/postinst" "$D/DEBIAN/postrm"

find "$D" -type d -exec chmod 755 {} +
dpkg-deb --root-owner-group -Zxz --build "$D" "$OUT/$PKG.deb"
dpkg-deb --info "$OUT/$PKG.deb"
echo "built $OUT/$PKG.deb"
