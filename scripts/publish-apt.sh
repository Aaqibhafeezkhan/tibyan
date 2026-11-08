#!/usr/bin/env bash
#
# Add a release's .deb to the signed Tibyan APT repository at
# https://apt.altibyan.app, driven from this Mac. Same shape as
# scripts/build-win-remote.sh: the server does the work in Docker.
#
# HOW
#   The release workflow attaches tibyan_<version>-<build>_amd64.deb to the
#   GitHub release. The server downloads it, and a throwaway reprepro container
#   (no network) adds it to the repository and signs the index. The signing key
#   never touches the server's disk: it is piped from ~/.config/tibyan over SSH
#   into the container's stdin and imported into a tmpfs keyring there.
#
# ISOLATION (shared host: never touch other projects)
#   state dir  /opt/tibyan-apt      (conf/, db/, www/ = reprepro output, backups/)
#   image      tibyan_apt:bookworm, container tibyan_apt_publish (--rm)
#   web root   /home/ahmedhelal/web/apt.altibyan.app/public_html (Hestia vhost)
#
# USAGE
#   scripts/publish-apt.sh                    # preflight (default, changes nothing)
#   scripts/publish-apt.sh --publish          # add the .deb, sign, sync, check
#   options: --tag vX.Y.Z   release tag (default: v<pubspec version>)
#
# ROLLBACK
#   Each publish first saves conf/, db/ and www/dists/ to
#   /opt/tibyan-apt/backups/repo-<UTC>.tgz. Old .deb files stay in the pool
#   (keepunreferencedfiles). To roll back on the server:
#     cd /opt/tibyan-apt && rm -rf db www/dists && tar xzf backups/repo-<UTC>.tgz
#     rsync -a --delete www/dists/ $WEB/dists/
#
# Keys: ~/.config/tibyan/apt-signing.key (private, chmod 600) and
# ~/.config/tibyan/apt-gpg.env (TIBYAN_APT_KEY_FPR). SSH: ~/.ssh/tibyan_deploy.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${TIBYAN_DEPLOY_HOST:-217.76.57.212}"
USER_="${TIBYAN_DEPLOY_USER:-root}"
KEY="${TIBYAN_DEPLOY_KEY:-$HOME/.ssh/tibyan_deploy}"
SIGNING_KEY="${TIBYAN_APT_SIGNING_KEY:-$HOME/.config/tibyan/apt-signing.key}"
GPG_ENV="$HOME/.config/tibyan/apt-gpg.env"
REMOTE_DIR="/opt/tibyan-apt"
WEB="/home/ahmedhelal/web/apt.altibyan.app/public_html"
URL="https://apt.altibyan.app"
OWNER="ahmedhelal:ahmedhelal"
IMAGE="tibyan_apt:bookworm"
REPO="helalrules7/tibyan"

PUBSPEC_VERSION="$(sed -n 's/^version: *//p' pubspec.yaml | head -1)"
MODE="preflight"; TAG="v${PUBSPEC_VERSION%%+*}"
while [ $# -gt 0 ]; do
  case "$1" in
    --preflight) MODE="preflight" ;;
    --publish)   MODE="publish" ;;
    --tag)       TAG="$2"; shift ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
  shift
done

SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o ConnectTimeout=25 -o BatchMode=yes)
_ssh() { ssh "${SSH_OPTS[@]}" "$USER_@$HOST" "$@"; }
_rsync() { rsync -az -e "ssh ${SSH_OPTS[*]}" "$@"; }

# ---------------------------------------------------------------------------
# Preflight (read-only)
# ---------------------------------------------------------------------------
echo "▶ Tibyan APT publish — tag $TAG — mode: $MODE"
fail=0
DEB="$(gh release view "$TAG" -R "$REPO" --json assets \
  -q '.assets[].name | select(test("^tibyan_.*_amd64\\.deb$"))' 2>/dev/null | head -1 || true)"
[ -n "$DEB" ] && echo "  .deb (GitHub): $TAG/$DEB" \
  || { echo "  ✗ no tibyan_*_amd64.deb on GitHub release $TAG (or gh not logged in)"; fail=1; }
DEB_VERSION="${DEB#tibyan_}"; DEB_VERSION="${DEB_VERSION%_amd64.deb}"
[ -f "$KEY" ] || { echo "  ✗ SSH key not found: $KEY"; fail=1; }
if [ -f "$SIGNING_KEY" ] && [ -f "$GPG_ENV" ]; then
  # shellcheck disable=SC1090
  . "$GPG_ENV"
  [ "$(stat -f %Lp "$SIGNING_KEY" 2>/dev/null || stat -c %a "$SIGNING_KEY")" = 600 ] \
    || { echo "  ✗ $SIGNING_KEY must be chmod 600"; fail=1; }
  grep -q "SignWith: ${TIBYAN_APT_KEY_FPR:-none}" linux/apt/conf/distributions \
    && echo "  signing key  : ${TIBYAN_APT_KEY_FPR} (matches conf/distributions)" \
    || { echo "  ✗ TIBYAN_APT_KEY_FPR does not match linux/apt/conf/distributions"; fail=1; }
else
  echo "  ✗ signing key or $GPG_ENV missing"; fail=1
fi
for f in Dockerfile conf/distributions conf/options setup.sh index.html tibyan.gpg tibyan.asc; do
  [ -f "linux/apt/$f" ] || { echo "  ✗ linux/apt/$f missing"; fail=1; }
done

echo "▶ Server $USER_@$HOST"
_ssh REMOTE_DIR="$REMOTE_DIR" WEB="$WEB" DEB_VERSION="$DEB_VERSION" bash -s <<'REMOTE' || fail=1
set -u
f=0
echo "  docker       : $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "  state dir    : $REMOTE_DIR $([ -d "$REMOTE_DIR/db" ] && echo '(repository exists)' || echo '(new repository)')"
[ -d "$WEB" ] && echo "  web root     : $WEB" || { echo "  ✗ web root $WEB missing (Hestia vhost apt.altibyan.app)"; f=1; }
if [ -f "$WEB/dists/stable/main/binary-amd64/Packages" ]; then
  echo "  published    : $(grep '^Version:' "$WEB/dists/stable/main/binary-amd64/Packages" | tr '\n' ' ')"
  grep -q "^Version: $DEB_VERSION\$" "$WEB/dists/stable/main/binary-amd64/Packages" \
    && echo "  ! $DEB_VERSION is already in the repository (publish is a no-op)"
fi
command -v docker >/dev/null && docker info >/dev/null 2>&1 || { echo "  ✗ docker not usable"; f=1; }
command -v rsync >/dev/null || { echo "  ✗ rsync missing"; f=1; }
[ "$f" = 0 ] && echo "  ✓ server ready" || exit 1
REMOTE
[ "$fail" = 0 ] || { echo "✗ preflight failed"; exit 1; }

if [ "$MODE" = preflight ]; then
  cat <<EOF

Plan for --publish:
  1. upload linux/apt/ (Dockerfile, conf, setup.sh, index.html, keys) to $REMOTE_DIR
  2. server downloads $DEB from the $TAG release
  3. back up conf/ db/ www/dists/ to $REMOTE_DIR/backups/repo-<UTC>.tgz
  4. reprepro includedeb stable + sign (key piped in, container without network)
  5. sync www/ and the static files to $WEB, check $URL over HTTPS

Preflight only — nothing on the server was changed.
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# Publish
# ---------------------------------------------------------------------------
echo "▶ Uploading repository config to $REMOTE_DIR"
_ssh "mkdir -p '$REMOTE_DIR/incoming' '$REMOTE_DIR/backups' '$REMOTE_DIR/static'"
_rsync linux/apt/Dockerfile "$USER_@$HOST:$REMOTE_DIR/"
_rsync --delete linux/apt/conf/ "$USER_@$HOST:$REMOTE_DIR/conf/"
_rsync linux/apt/setup.sh linux/apt/index.html linux/apt/tibyan.gpg linux/apt/tibyan.asc \
  "$USER_@$HOST:$REMOTE_DIR/static/"

echo "▶ Server downloads $DEB, backs up the repository, builds the image"
_ssh REMOTE_DIR="$REMOTE_DIR" DEB="$DEB" TAG="$TAG" REPO="$REPO" IMAGE="$IMAGE" bash -s <<'REMOTE'
set -euo pipefail
cd "$REMOTE_DIR"
curl -fsSL --retry 3 -o "incoming/$DEB.part" "https://github.com/$REPO/releases/download/$TAG/$DEB"
mv -f "incoming/$DEB.part" "incoming/$DEB"
dpkg-deb --field "incoming/$DEB" Package Version 2>/dev/null || ls -la "incoming/$DEB"
TS=$(date -u +%Y%m%dT%H%M%SZ)
if [ -d db ]; then
  tar czf "backups/repo-$TS.tgz" conf db www/dists
  echo "  backup: $REMOTE_DIR/backups/repo-$TS.tgz"
fi
docker build -q -t "$IMAGE" . </dev/null
REMOTE

echo "▶ Adding to the repository and signing (key over stdin)"
# The container gets the private key on stdin only; GNUPGHOME is a tmpfs.
_ssh "docker run --rm -i --name tibyan_apt_publish --network none \
  --tmpfs /gnupg:mode=0700 -e GNUPGHOME=/gnupg \
  -v $REMOTE_DIR:/repo $IMAGE sh -euc '
    gpg --batch --quiet --import
    reprepro -b /repo --keepunreferencedfiles includedeb stable /repo/incoming/$DEB
    reprepro -b /repo export stable
    gpgv --keyring /repo/static/tibyan.gpg /repo/www/dists/stable/InRelease
    reprepro -b /repo list stable'" < "$SIGNING_KEY"

echo "▶ Syncing to $WEB"
_ssh REMOTE_DIR="$REMOTE_DIR" WEB="$WEB" OWNER="$OWNER" DEB="$DEB" bash -s <<'REMOTE'
set -euo pipefail
cd "$REMOTE_DIR"
# pool first, then the indexes, so a reader never sees an index without its file.
rsync -a www/pool/ "$WEB/pool/"
rsync -a --delay-updates --delete www/dists/ "$WEB/dists/"
cp -f static/setup.sh static/index.html static/tibyan.gpg static/tibyan.asc "$WEB/"
chown -R "$OWNER" "$WEB"
find "$WEB" -type d -exec chmod 755 {} +; find "$WEB" -type f -exec chmod 644 {} +
rm -f "incoming/$DEB"
REMOTE

echo "▶ Checking $URL"
for p in tibyan.gpg setup.sh dists/stable/InRelease dists/stable/main/binary-amd64/Packages; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/$p")
  echo "  $p -> $code"; [ "$code" = 200 ] || exit 1
done
curl -fsS "$URL/dists/stable/main/binary-amd64/Packages" | grep -q "^Version: $DEB_VERSION\$" \
  && echo "✓ $DEB_VERSION is live at $URL" || { echo "✗ $DEB_VERSION not in the live Packages"; exit 1; }
