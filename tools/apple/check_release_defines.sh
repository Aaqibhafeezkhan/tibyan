#!/bin/sh
# Stops an App Store / TestFlight archive (iOS and macOS) that would ship
# without crash reports: the archive (xcodebuild ACTION=install, Release)
# must carry SENTRY_DSN and TIBYAN_CHANNEL in Flutter's DART_DEFINES, i.e.
# `flutter build ios|macos --release --config-only \
#    --dart-define-from-file=$HOME/.config/tibyan/sentry.env \
#    --dart-define=TIBYAN_CHANNEL=testflight|production`
# before `xcodebuild ... archive`. Plain builds (CI, `flutter run`) pass.
# Called from the Flutter build phase of both Runner projects.
[ "$ACTION" = "install" ] || exit 0
[ "$CONFIGURATION" = "Release" ] || exit 0
missing=""
for key in SENTRY_DSN TIBYAN_CHANNEL; do
  found=0
  for d in $(echo "$DART_DEFINES" | tr ',' ' '); do
    case "$(echo "$d" | base64 --decode 2>/dev/null)" in
      "$key="?*) found=1 ;;
    esac
  done
  [ "$found" = 1 ] || missing="$missing $key"
done
if [ -n "$missing" ]; then
  echo "error: release archive without$missing in DART_DEFINES: it would send no crash reports. Run flutter build ... --config-only with --dart-define-from-file=\$HOME/.config/tibyan/sentry.env --dart-define=TIBYAN_CHANNEL=<testflight|production> first (docs/RELEASE.md)." >&2
  exit 1
fi
exit 0
