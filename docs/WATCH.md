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

### Apple Watch (not embedded in the iOS app yet)

The watch target builds but is not part of the iOS app, so `flutter build
ios` and uploads are unchanged until these steps are done:

1. developer.apple.com > Identifiers > + App ID:
   - `app.tibyan.tibyan.watchkitapp`
   - `app.tibyan.tibyan.watchkitapp.widgets` (optional App Group
     `group.app.tibyan.tibyan` capability on both).
2. On the Mac: `ruby tools/apple/add_watch_target.rb --embed` (adds the
   watch app to Runner's «Embed Watch Content» and sets its
   `WKCompanionAppBundleIdentifier`). From then on Flutter sees a watch
   companion: `flutter build ios --simulator` needs `-d <simulator id>`
   (`flutter devices`).
3. Open `ios/Runner.xcworkspace` > targets TibyanWatch and
   TibyanWatchWidgets > Signing: team as for Runner, automatic. Add an
   AppIcon (1024 px) in a watch asset catalog.
4. Set TibyanWatch and TibyanWatchWidgets version/build to match the app
   before each release (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
5. Test: run Runner on the iPhone simulator paired with a Watch simulator,
   then archive as usual; the watch app ships inside the iOS app.

### Wear OS

1. Build: `cd android && ./gradlew :wear:bundleRelease` (signed with the
   phone's upload key from `android/key.properties`).
2. Play Console > Test and release > Advanced settings > Form factors > add
   Wear OS; accept the Wear OS review rules; add at least one Wear
   screenshot.
3. Upload the wear bundle to the Wear OS track (internal testing first).
   Its `versionCode` (900001 and up) must differ from every phone build.
