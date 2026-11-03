# Huawei watches («تبيان» على ساعات هواوي)

The Huawei counterpart of the Wear OS / Apple Watch app (docs/WATCH.md):
«ورد اليوم» (today's portion: surah name, page range, khatma percent, all
sent by the phone) and «المسبحة» (counts go back to the phone and join its
own per-device daily counter). Only the Huawei AppGallery build
(`--dart-define=TIBYAN_STORE=huawei`) has it; the Play build is unchanged.

## 1. Which watches

| Kind | Models | App type | Covered |
|---|---|---|---|
| Lite wearables | Watch GT 2/2 Pro/3/3 Pro/4/5/5 Pro/6, Watch Fit 2/3/4, Watch D, Band 7+ | JS lite wearable (FA model), DevEco Studio | **Yes, this project** |
| HarmonyOS smart wearables | Watch 3, Watch 4/4 Pro, Watch 5, Watch Ultimate | Java/JS (HarmonyOS 2-4) or ArkTS (HarmonyOS NEXT) | Not yet: a second, smart-wearable package |
| Mibro and other RTOS watches | | no third-party apps | No (phone notifications only) |

The GT and Fit lines are most Huawei watches sold, and Wear Engine's lite
wearable P2P API works with Android phones through Huawei Health, so this
project starts there. The Watch 4/5 can follow with the same data keys and
message contract.

## 2. How it works

- Phone: `android/app/src/huawei/kotlin/.../WatchBridge.kt` (only in the
  Huawei build; the Play build keeps `src/gms` and play-services-wearable).
  Same `app.tibyan/watch` channel and `push` call as Wear OS, so no Dart
  change and nothing edition-specific: the 1441 and 1405 editions push the
  same keys (their own page numbers), so both work identically.
- SDK: `com.huawei.hms:wearengine:5.0.3.300` from
  `https://developer.huawei.com/repo/` (added only when `TIBYAN_STORE=huawei`).
- Phone → watch: one P2P message, JSON of the Wear OS `/tibyan/state` keys
  (`portion_/surah_/from_/to_<yyyy-MM-dd>` for the next 3 days, `progress`,
  `idle`, `tasbih_dhikr`, `tasbih_target`, `tasbih_stages`,
  `tasbih_stage_texts`).
- Watch → phone: `{"total": N}`, the watch's running count. The phone adds
  `N - last seen` (per watch uuid) to the tasbih widget's pending counts,
  exactly like `/tibyan/taps` on Wear OS.
- Wear Engine cannot wake the phone app. The watch keeps its total and
  sends it again when the phone pushes (each time Tibyan opens or the
  khatma/dhikr changes), so no count is lost.
- First run: the phone asks for the Wear Engine «device manager» permission
  through Huawei Health (one system dialog).

Watch app: `wear_huawei/` (bundle `app.tibyan.watch`), pages
`index` («ورد اليوم») and `misbaha`; data logic in `common/data.js` mirrors
`android/wear/.../WatchData.kt`. Look: the «ليل هندسي» background
(`tile_background.png` at 466 px), gold arc, cream text. Lite wearables
can't load custom fonts, so the system font replaces Changa/IBM Plex.
Gestures: swipe up for the misbaha; tap counts; swipe down or long-press
for «ابدأ من جديد» / «ورد اليوم».

## 3. Build the watch app

DevEco Studio is not installed on the build Mac and needs a Huawei login,
so the watch app has not been compiled yet.

1. Install DevEco Studio 3.1 (the last one with Lite Wearable FA templates)
   from developer.huawei.com, sign in, install the "Lite Wearable" SDK
   (API 8 / compatible 8).
2. Download the Wear Engine **lite wearable JS SDK** (Wear Engine → SDK
   download) and copy `wearengine.js` to
   `wear_huawei/entry/src/main/js/default/common/wearengine.js`
   (git-ignored). Check its `Builder`/`Message` usage against
   `common/data.js` `sendTotal()`; older SDKs set the builder with
   `message.builder = builder`, newer ones with `new Message(builder)`.
3. Open `wear_huawei/` in DevEco, let it sync, then **File → Project
   Structure → Signing Configs**: sign in and let it generate the debug
   certificate (stays out of git).
4. Fingerprints (public ids, not secrets):
   - in `common/data.js` set `PHONE_FINGERPRINT` to the SHA-256 of the phone
     app's AppGallery signing certificate (AGC → app → App signing),
   - in `WatchBridge.kt` (src/huawei) set `WATCH_FINGERPRINT` to the watch
     app's fingerprint from AGC (Wear Engine → watch app info).
   While either is empty that side stays silent.
5. Build → Build Hap(s): `entry/build/default/outputs/default/entry-default-signed.hap`.
   From the terminal: `./hvigorw assembleHap` in `wear_huawei/`.
6. Test: a GT/Fit watch paired in Huawei Health, the Huawei phone APK
   (docs/HUAWEI.md section 2) installed, then DevEco's run button (or the
   Huawei Health developer mode sideload).

## 4. AppGallery Connect

1. Apply for Wear Engine: developer.huawei.com → Console → Wear Engine →
   apply, permission «Device management» + «P2P messaging»; link the phone
   app `app.tibyan.tibyan`. Review takes a few working days.
2. AGC → My apps → New app → **HarmonyOS → Lite wearable**, bundle
   `app.tibyan.watch`, name «تبيان»; link it to the phone app as its
   companion.
3. Screenshots: `docs/brand/store/screenshots/huawei_watch/{ar,en}/466x466`
   (Watch GT 4/5, Watch 4/5) and `454x454` (GT 2/3). Upload whichever size
   the form asks for; icon `huawei_watch/icon-216.png`. These are the Wear
   OS screenshots scaled; same content, same look.
4. Release certificate + profile in AGC (Certificates/Profiles), sign the
   release HAP in DevEco, upload, submit with the review note: "Companion of
   Tibyan (app.tibyan.tibyan). Shows today's Quran reading portion sent by
   the phone and a tasbih counter whose counts sync back. No ads, no account."
