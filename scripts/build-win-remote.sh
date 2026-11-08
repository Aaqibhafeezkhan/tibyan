#!/usr/bin/env bash
#
# Build the Tibyan Windows installer (NSIS) on our Linux server, in Docker,
# from the Flutter zip the GitHub release workflow already produced, and
# optionally publish it with the auto-update feed (latest.json).
#
# WHY THIS SHAPE
#   The release workflow builds the Flutter app on windows-latest and attaches
#   tibyan-windows-x64.zip to the GitHub release. Packaging that folder into a
#   Setup.exe needs only makensis, which runs natively on Linux (no Wine), so
#   the server does it in a small debian+nsis container. Nothing is installed on
#   the host; only Docker is used.
#
# ISOLATION (same host as other projects: never touch them)
#   build dir  /opt/tibyan-winbuild
#   compose    project tibyan_winbuild, container tibyan_winbuild_nsis,
#              image tibyan_nsis:bookworm, no volumes, no network in the build
#   publish    /home/ahmedhelal/web/tibyan.ahmedhelal.dev/public_html/win
#              -> https://tibyan.ahmedhelal.dev/win/
#
# USAGE
#   scripts/build-win-remote.sh                       # preflight (default, changes nothing)
#   scripts/build-win-remote.sh --build               # build on the server, no publish
#   scripts/build-win-remote.sh --build --publish     # build + publish exe and latest.json
#   options: --zip <path>   use a local zip instead of the GitHub release asset
#            --tag vX.Y.Z   release tag to download (default: v<pubspec version>)
#            --notes "..."  short release notes for latest.json
#            --fetch        copy the built exe back to build/windows-installer/
#
# Rollback of a publish: the previous latest.json is kept as
# win/backups/latest-<UTC>.json; copy it back over win/latest.json. Old exe
# files are never deleted, so the previous URL still works.
#
# Auth: SSH key (TIBYAN_DEPLOY_KEY, default ~/.ssh/tibyan_deploy). No passwords.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${TIBYAN_DEPLOY_HOST:-217.76.57.212}"
USER_="${TIBYAN_DEPLOY_USER:-root}"
KEY="${TIBYAN_DEPLOY_KEY:-$HOME/.ssh/tibyan_deploy}"
REMOTE_DIR="/opt/tibyan-winbuild"
PUB_DIR="/home/ahmedhelal/web/tibyan.ahmedhelal.dev/public_html/win"
PUB_URL="https://tibyan.ahmedhelal.dev/win"
PUB_OWNER="ahmedhelal:ahmedhelal"
PROJECT="tibyan_winbuild"
REPO="helalrules7/tibyan"
ZIP_NAME="tibyan-windows-x64.zip"

PUBSPEC_VERSION="$(sed -n 's/^version: *//p' pubspec.yaml | head -1)"
VERSION="${PUBSPEC_VERSION%%+*}"
BUILD="${PUBSPEC_VERSION##*+}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD" =~ ^[0-9]+$ ]] \
  || { echo "cannot read version+build from pubspec.yaml"; exit 2; }

MODE="preflight"; PUBLISH=0; FETCH=0; ZIP=""; TAG="v$VERSION"; NOTES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --preflight) MODE="preflight" ;;
    --build)     MODE="build" ;;
    --publish)   PUBLISH=1 ;;
    --fetch)     FETCH=1 ;;
    --zip)       ZIP="$2"; shift ;;
    --tag)       TAG="$2"; shift ;;
    --notes)     NOTES="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
  shift
done
[ "$PUBLISH" = 1 ] && [ "$MODE" != build ] && { echo "--publish needs --build"; exit 2; }

EXE="Tibyan-Windows-Setup-v${VERSION}.exe"
SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o ConnectTimeout=25 -o BatchMode=yes)
_ssh() { ssh "${SSH_OPTS[@]}" "$USER_@$HOST" "$@"; }
_rsync() { rsync -az -e "ssh ${SSH_OPTS[*]}" "$@"; }

# ---------------------------------------------------------------------------
# Preflight: local inputs, then the server. Read-only everywhere.
# ---------------------------------------------------------------------------
echo "▶ Tibyan ${VERSION} (build ${BUILD}) — mode: ${MODE}$([ $PUBLISH = 1 ] && echo ' + publish')"
fail=0
if [ -n "$ZIP" ]; then
  [ -f "$ZIP" ] && echo "  zip (local)  : $ZIP ($(du -h "$ZIP" | cut -f1))" \
    || { echo "  ✗ zip not found: $ZIP"; fail=1; }
else
  if command -v gh >/dev/null && sz=$(gh release view "$TAG" -R "$REPO" --json assets \
      -q ".assets[] | select(.name==\"$ZIP_NAME\") | .size" 2>/dev/null) && [ -n "$sz" ]; then
    echo "  zip (GitHub) : $TAG/$ZIP_NAME ($((sz / 1000000)) MB)"
  else
    echo "  ✗ $ZIP_NAME not found on GitHub release $TAG (or gh not logged in)"; fail=1
  fi
fi
[ -f windows/installer/tibyan.nsi ] || { echo "  ✗ windows/installer/tibyan.nsi missing"; fail=1; }
[ -f "$KEY" ] || { echo "  ✗ SSH key not found: $KEY"; fail=1; }

echo "▶ Server $USER_@$HOST"
_ssh REMOTE_DIR="$REMOTE_DIR" PUB_DIR="$PUB_DIR" PROJECT="$PROJECT" EXE="$EXE" bash -s <<'REMOTE' || fail=1
set -u
f=0
echo "  arch         : $(uname -m)"
echo "  disk /opt    : $(df -h /opt | awk 'NR==2{print $4" free"}')"
echo "  docker       : $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "  compose      : $(docker compose version --short 2>/dev/null || echo 'NOT AVAILABLE')"
echo "  rsync        : $(command -v rsync >/dev/null && echo present || echo 'NOT INSTALLED')"
echo "  build dir    : $REMOTE_DIR $([ -d "$REMOTE_DIR" ] && echo '(exists)' || echo '(will be created)')"
echo "  publish dir  : $PUB_DIR $([ -d "$PUB_DIR" ] && echo '(exists)' || echo '(will be created)')"
[ -d "$(dirname "$PUB_DIR")" ] || { echo "  ✗ web root $(dirname "$PUB_DIR") missing"; f=1; }
[ -f "$PUB_DIR/latest.json" ] && echo "  live feed    : $(tr -d '\n' < "$PUB_DIR/latest.json" | cut -c1-160)"
[ -f "$PUB_DIR/$EXE" ] && echo "  ! $EXE is already published (a publish would replace it)"
others=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -c '^tibyan_winbuild' || true)
echo "  our containers: ${others} (tibyan_winbuild*)"
command -v docker >/dev/null || { echo "  ✗ docker missing"; f=1; }
docker compose version >/dev/null 2>&1 || { echo "  ✗ docker compose v2 missing"; f=1; }
docker info >/dev/null 2>&1 || { echo "  ✗ docker daemon not reachable"; f=1; }
command -v rsync >/dev/null || { echo "  ✗ rsync missing on the server"; f=1; }
avail=$(df -Pk /opt | awk 'NR==2{print $4}')
[ "${avail:-0}" -ge 2000000 ] || { echo "  ✗ less than 2 GB free on /opt"; f=1; }
[ "$f" = 0 ] && echo "  ✓ server can build the installer" || exit 1
REMOTE
[ "$fail" = 0 ] || { echo "✗ preflight failed"; exit 1; }

if [ "$MODE" = "preflight" ]; then
  cat <<EOF

Plan for --build:
  1. upload windows/installer/* + app icon to $HOST:$REMOTE_DIR; get $ZIP_NAME ($TAG) there
  2. docker compose -p $PROJECT build + run (makensis) -> $REMOTE_DIR/out/$EXE
  3. write $REMOTE_DIR/out/latest.json (version, build, url, sha256, size)
With --publish:
  4. back up $PUB_DIR/latest.json, copy $EXE then latest.json (last) to $PUB_DIR
  5. check $PUB_URL/latest.json and the exe over HTTPS

Preflight only — nothing on the server was changed.
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
STAGE="build/windows-installer"
rm -rf "$STAGE"; mkdir -p "$STAGE"
# A local zip travels with the stage; otherwise the server downloads the public
# release asset itself (much faster than uploading ~125 MB from a laptop).
[ -n "$ZIP" ] && cp "$ZIP" "$STAGE/$ZIP_NAME"
cp windows/installer/tibyan.nsi windows/installer/Dockerfile windows/installer/docker-compose.win-nsis.yml "$STAGE/"
cp windows/runner/resources/app_icon.ico "$STAGE/app_icon.ico"

echo "▶ Uploading to $HOST:$REMOTE_DIR"
_ssh "mkdir -p '$REMOTE_DIR'"
_rsync --delete --exclude out/ $([ -z "$ZIP" ] && echo "--exclude $ZIP_NAME") \
  "$STAGE/" "$USER_@$HOST:$REMOTE_DIR/"
if [ -z "$ZIP" ]; then
  echo "▶ Server downloads $TAG/$ZIP_NAME from GitHub"
  _ssh "cd '$REMOTE_DIR' && curl -fsSL --retry 3 -o '$ZIP_NAME.part' \
    'https://github.com/$REPO/releases/download/$TAG/$ZIP_NAME' && mv -f '$ZIP_NAME.part' '$ZIP_NAME' && ls -la '$ZIP_NAME'"
fi

echo "▶ Building $EXE in Docker"
_ssh VERSION="$VERSION" BUILD="$BUILD" REMOTE_DIR="$REMOTE_DIR" PROJECT="$PROJECT" \
  EXE="$EXE" PUB_URL="$PUB_URL" NOTES="$(printf %q "$NOTES")" bash -s <<'REMOTE'
set -euo pipefail
cd "$REMOTE_DIR"
rm -f out/*.exe out/latest.json
# </dev/null: this script itself arrives on stdin, and docker would eat the rest.
docker compose -p "$PROJECT" -f docker-compose.win-nsis.yml build --pull nsis </dev/null
docker compose -p "$PROJECT" -f docker-compose.win-nsis.yml run -T --rm nsis </dev/null
test -s "out/$EXE"
SHA=$(sha256sum "out/$EXE" | cut -d' ' -f1)
SIZE=$(stat -c%s "out/$EXE")
python3 - "$VERSION" "$BUILD" "$PUB_URL/$EXE" "$SHA" "$SIZE" "$NOTES" > out/latest.json <<'PY'
import json, sys
v, b, url, sha, size, notes = sys.argv[1:]
d = {"version": v, "build": int(b), "url": url, "sha256": sha, "size": int(size)}
if notes:
    d["notes"] = notes
print(json.dumps(d, ensure_ascii=False, indent=2))
PY
echo "  built: out/$EXE  size=$SIZE  sha256=$SHA"
cat out/latest.json
REMOTE

if [ "$FETCH" = 1 ]; then
  rsync -az -e "ssh ${SSH_OPTS[*]}" "$USER_@$HOST:$REMOTE_DIR/out/" "$STAGE/out/"
  echo "✓ Copied to $STAGE/out/"
fi

[ "$PUBLISH" = 1 ] || { echo "✓ Built on $HOST:$REMOTE_DIR/out (not published)"; exit 0; }

# ---------------------------------------------------------------------------
# Publish: verify, back up the old feed, exe first, latest.json last.
# ---------------------------------------------------------------------------
echo "▶ Publishing to $PUB_DIR"
_ssh REMOTE_DIR="$REMOTE_DIR" PUB_DIR="$PUB_DIR" EXE="$EXE" PUB_OWNER="$PUB_OWNER" bash -s <<'REMOTE'
set -euo pipefail
cd "$REMOTE_DIR/out"
DECL=$(python3 -c 'import json;print(json.load(open("latest.json"))["sha256"])')
CALC=$(sha256sum "$EXE" | cut -d' ' -f1)
[ "$DECL" = "$CALC" ] || { echo "sha256 MISMATCH — refusing to publish"; exit 1; }
mkdir -p "$PUB_DIR/backups"
TS=$(date -u +%Y%m%dT%H%M%SZ)
[ -f "$PUB_DIR/latest.json" ] && cp -p "$PUB_DIR/latest.json" "$PUB_DIR/backups/latest-$TS.json"
cp -f "$EXE" "$PUB_DIR/.$EXE.part" && mv -f "$PUB_DIR/.$EXE.part" "$PUB_DIR/$EXE"
cp -f latest.json "$PUB_DIR/.latest.json.part" && mv -f "$PUB_DIR/.latest.json.part" "$PUB_DIR/latest.json"
chown -R "$PUB_OWNER" "$PUB_DIR"
chmod 755 "$PUB_DIR" "$PUB_DIR/backups"; chmod 644 "$PUB_DIR/$EXE" "$PUB_DIR/latest.json"
echo "  published; feed backup: backups/latest-$TS.json"
REMOTE

echo "▶ Checking over HTTPS"
curl -fsS "$PUB_URL/latest.json?check=$(date +%s)"; echo
code=$(curl -s -o /dev/null -w '%{http_code}' -I "$PUB_URL/$EXE")
echo "  $PUB_URL/$EXE -> $code"
[ "$code" = 200 ] || { echo "✗ installer URL not reachable"; exit 1; }
echo "✓ Published. If Cloudflare caches latest.json, purge it (the exe is version-immutable)."
