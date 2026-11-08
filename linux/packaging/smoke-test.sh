#!/usr/bin/env bash
#
# Smoke-test the Linux packages in clean containers (needs Docker).
#
#   linux/packaging/smoke-test.sh <dir with tibyan_*.deb and tibyan-*.AppImage>
#   DISTROS="debian:12" linux/packaging/smoke-test.sh out/   # one distro
#
# .deb    : apt installs it (resolving Depends), every ELF file in /opt/tibyan
#           and libmpv resolve all their libraries, and the app starts under
#           Xvfb and is still running after 15 s.
# AppImage: on a system with GTK but WITHOUT mpv, the extracted AppImage's
#           libraries all resolve (bundled libmpv included) and it starts.
set -euo pipefail
DIR="$(cd "$1" && pwd)"
DISTROS="${DISTROS:-ubuntu:22.04 debian:12 ubuntu:24.04}"
DEB="$(cd "$DIR" && ls tibyan_*_amd64.deb | head -1)"
APPIMAGE="$(cd "$DIR" && ls tibyan-*-x86_64.AppImage 2>/dev/null | head -1 || true)"

# Runs inside the container. $1 = mode (deb|appimage), $2 = file name.
read -r -d '' INNER <<'SH' || true
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
nf() { ldd "$@" 2>&1 | grep 'not found' && return 1 || return 0; }
start() {  # the app must still be running after 15 s (timeout -> 124)
  set +e
  timeout 15 xvfb-run -a "$@" >/tmp/run.log 2>&1; rc=$?
  set -e
  [ "$rc" = 124 ] || { echo "app exited early ($rc):"; tail -30 /tmp/run.log; return 1; }
  echo "  started and stayed up 15 s"
}
if [ "$1" = deb ]; then
  apt-get install -y -qq "/pkg/$2" xvfb xauth >/dev/null
  dpkg -s tibyan | sed -n 's/^Depends: /  Depends: /p'
  find /opt/tibyan -type f \( -name '*.so*' -o -name tibyan \) | while read -r f; do
    nf "$f" || { echo "  unresolved in $f"; exit 1; }
  done
  m=$(ldconfig -p | awk '/libmpv\.so\.[12] /{print $NF; exit}')
  [ -n "$m" ] && nf "$m" || { echo "  libmpv missing or broken"; exit 1; }
  echo "  libraries OK (libmpv: $m)"
  command -v tibyan >/dev/null
  start tibyan
else
  apt-get install -y -qq libgtk-3-0 xvfb xauth >/dev/null 2>&1 \
    || apt-get install -y -qq libgtk-3-0t64 xvfb xauth >/dev/null
  if ldconfig -p | grep -q libmpv; then echo "  mpv is installed; test is meaningless"; exit 1; fi
  cd /tmp && cp "/pkg/$2" app.AppImage && chmod +x app.AppImage
  ./app.AppImage --appimage-extract >/dev/null
  R=/tmp/squashfs-root
  export LD_LIBRARY_PATH="$R/usr/lib/tibyan/lib:$R/usr/lib"
  for f in "$R/usr/lib/tibyan/tibyan" "$R"/usr/lib/tibyan/lib/*.so "$R"/usr/lib/libmpv.so*; do
    nf "$f" || { echo "  unresolved in $f"; exit 1; }
  done
  unset LD_LIBRARY_PATH
  echo "  libraries OK (bundled $(ls $R/usr/lib | grep -c '\.so') libs)"
  start "$R/AppRun"
fi
SH

fail=0
for d in $DISTROS; do
  echo "▶ .deb on $d"
  docker run --rm --platform linux/amd64 -v "$DIR:/pkg:ro" "$d" bash -c "$INNER" _ deb "$DEB" \
    && echo "✓ $d deb" || { echo "✗ $d deb"; fail=1; }
  if [ -n "$APPIMAGE" ]; then
    echo "▶ AppImage on $d"
    docker run --rm --platform linux/amd64 -v "$DIR:/pkg:ro" "$d" bash -c "$INNER" _ appimage "$APPIMAGE" \
      && echo "✓ $d AppImage" || { echo "✗ $d AppImage"; fail=1; }
  fi
done
exit "$fail"
