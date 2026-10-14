#!/usr/bin/env bash
# Regenerates the native launch screens from assets/brand/tibyan_logo.svg so
# they match the first frame of the Flutter splash (lib/features/splash):
# the logo 112 dp high, centred, in the «هندسي» colours (day: #0F6660 on
# #F6F1E8; night: #55BDB2 on #0E1A1B). Needs rsvg-convert and ImageMagick.
set -euo pipefail
cd "$(dirname "$0")/.."
SVG=assets/brand/tibyan_logo.svg
RES=android/app/src/main/res
IOS=ios/Runner/Assets.xcassets/LaunchImage.imageset
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

logo() { # colour height out
  sed "s/fill=\"#000\"/fill=\"$1\"/" "$SVG" > "$TMP/l.svg"
  rsvg-convert -h "$2" "$TMP/l.svg" -o "$3"
}

for pair in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  d=${pair%%:*}; s=${pair##*:}
  h=$(python3 -c "print(round(112*$s))")
  c=$(python3 -c "print(round(288*$s))")
  for mode in day night; do
    if [ $mode = day ]; then col='#0F6660'; dir=$RES/drawable-$d; else col='#55BDB2'; dir=$RES/drawable-night-$d; fi
    mkdir -p "$dir"
    logo "$col" "$h" "$dir/launch_logo.png"
    # Android 12+: the icon on a 288 dp canvas, the logo at the same size.
    magick -size "${c}x${c}" xc:none "$dir/launch_logo.png" -gravity center \
      -composite "$dir/android12_splash.png"
  done
done

for s in 1 2 3; do
  suffix=$([ $s = 1 ] && echo "" || echo "@${s}x")
  logo '#0F6660' $((112 * s)) "$IOS/LaunchImage$suffix.png"
  logo '#55BDB2' $((112 * s)) "$IOS/LaunchImageDark$suffix.png"
done
echo "native splash regenerated"
