# Watch: Apple Watch app, complications and Wear OS tile

What the watch shows comes only from the phone: today's portion of the
khatma (the home screen widget's keys: `title`, `idle`, `days`,
`portion_<yyyy-MM-dd>`, `ref_<yyyy-MM-dd>`, i.e. a page range and the surah
name + verse number it starts at, from content data) and the current dhikr
(`tasbih_dhikr`, `tasbih_count`, `tasbih_label`). No Quran text is shown.

Counts made on the watch's misbaha go to the phone and join the misbaha's
pending counts (`tasbih_pending`, the same store as the home screen
widget's). They are added to the phone's count immediately in the background
and update the home widget and sync too.

## Flow

- Dart: `lib/core/platform/watch_bridge.dart` (`app.tibyan/watch`, method
  `push`) is called by `PluginHomeWidgetSync.write` and
  `ChannelTasbihPlatform.writeWidget`.
- iOS: `WatchChannel` in `ios/Runner/AppDelegate.swift`. Merges the entries
  (kept in UserDefaults), sends them as the WatchConnectivity application
  context. Watch counts arrive as `transferUserInfo(["tasbih_add": n])`
  (queued by the system), are added to the App Group's `tasbih_pending`,
  then `pendingAdded` is invoked on `app.tibyan/tasbih`.
- watchOS app and complication:
  - App: `apple/TibyanWatch/` (SwiftUI, two vertical pages: «ورد اليوم» and
    «المسبحة»), target `TibyanWatch` in `ios/Runner.xcodeproj`, bundle id
    `app.tibyan.tibyan.watchkitapp`, watchOS 10+. Strings in
    `ar.lproj`/`en.lproj/Localizable.strings`.
  - Complication: `TibyanWatchWidgets.swift` (WidgetKit accessoryCircular,
    accessoryRectangular, accessoryInline, accessoryCorner for today's
    wird progress), target `TibyanWatchWidgets`, bundle id
    `app.tibyan.tibyan.watchkitapp.widgets`, embedded in `TibyanWatch`.
- Android: `WatchBridge.kt` puts the Data Layer item `/tibyan/state`;
  `WatchListenerService` reads `/tibyan/taps` (a running total per watch;
  the phone adds what is new to `tasbih_pending`).
- Wear OS app and complication:
  - Module `android/wear` (same application id `app.tibyan.tibyan`, minSdk 30).
  - Tile: `WirdTileService` (tile) and `TasbihActivity` (misbaha).
  - Complication: `WirdComplicationService` (data source for SHORT_TEXT and
    LONG_TEXT complications showing today's wird).
  - Strings in `res/values` and `res/values-ar`.

## Build checks

```sh
xcodebuild -project ios/Runner.xcodeproj -target TibyanWatch \
  -sdk watchsimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/Runner.xcodeproj -target TibyanWatchWidgets \
  -sdk watchsimulator CODE_SIGNING_ALLOWED=NO build
cd android && ./gradlew :wear:assembleDebug
```

## Gated: what the owner must do

### Apple Watch (embedded, set up 2026-10-26)

The watch app ships inside the iOS app (Runner > «Embed Watch Content»).
`tools/apple/add_watch_target.rb --embed` sets it all up and can be re-run:

- Signing: team `T958VWM76Z`. Debug signs automatically; Release/Profile
  sign manually like Runner, with the App Store profiles «Tibyan Watch
  AppStore» and «Tibyan Watch Widgets AppStore» (Runner uses «Tibyan
  AppStore 2026-10», which has iCloud and Associated Domains). An
  automatically signed watch app inside the manually signed Runner fails
  with "Embedded binary is not signed with the same certificate".
- App Group `group.app.tibyan.tibyan` for both targets
  (`apple/TibyanWatch/TibyanWatch.entitlements`).
- Icon: `apple/TibyanWatch/Assets.xcassets/AppIcon.appiconset`, one 1024 px
  watchOS image (the phone's App Store icon).
- Version: both targets use `ios/Flutter/Watch.xcconfig`, so
  `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` follow
  `FLUTTER_BUILD_NAME`/`FLUTTER_BUILD_NUMBER` (pubspec or `--build-name` /
  `--build-number`), the same as Runner. Nothing to match by hand.
- Flutter now sees a watch companion: `flutter build ios --simulator`
  needs `-d <simulator id>` (`flutter devices`).

Archive (as in handoff «Releases»; key flags as a zsh array):

```sh
flutter build ios --release --config-only --build-number=N \
  --dart-define-from-file=$HOME/.config/tibyan/google.env
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates "${K[@]}" archive -archivePath <path>.xcarchive
```

The archive holds `Runner.app/Watch/TibyanWatch.app` with
`PlugIns/TibyanWatchWidgets.appex`.

### Wear OS

1. Build: `cd android && ./gradlew :wear:bundleRelease` (signed with the
   phone's upload key from `android/key.properties`).
2. Play Console > Test and release > Advanced settings > Form factors > add
   Wear OS; accept the Wear OS review rules (Ahmed); add the Wear
   screenshots from `docs/brand/play/wear/`.
3. Upload the wear bundle to the Wear OS track (internal testing first).
   Its `versionCode` (900001 and up) must differ from every phone build.
