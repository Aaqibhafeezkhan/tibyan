# Huawei watches («تبيان» على ساعات هواوي)

The Huawei counterpart of the Wear OS / Apple Watch app (docs/WATCH.md):
«ورد اليوم» (today's portion: surah name, page range, khatma percent, all
sent by the phone) and «المسبحة» (counts on the watch alone). The link is
**one-way, phone → watch** (section 2). Only the Huawei AppGallery build
(`--dart-define=TIBYAN_STORE=huawei`) has it; the Play build is unchanged.

## 1. Which watches

From Huawei's Wear Engine «Supported devices» table (checked 2026-11):
the GT, FIT and D series run the **lite wearable OS** (JS lite wearable
apps); the WATCH and WATCH Ultimate series are **smart wearables**
(HarmonyOS, Java/JS or ArkTS). Huawei asks new apps to target the latest
models, not WATCH 4 / WATCH FIT 2.

| Kind | Target models | App type | Covered |
|---|---|---|---|
| Lite wearables | **Watch GT 5 / GT 5 Pro, Watch GT 6 / GT 6 Pro, Watch Fit 3, Watch Fit 4 / Fit 4 Pro** (older GT 3/4 work too) | JS lite wearable (FA model), DevEco Studio | **Yes, this project** |
| Smart wearables | Watch 5, Watch Ultimate / Ultimate 2 | HarmonyOS smart-wearable package (ArkTS) | Not yet: a second package, same message contract |
| Mibro and other RTOS watches | | no third-party apps | No (phone notifications only) |

## 2. How it works

- Phone: `android/app/src/huawei/kotlin/.../WatchBridge.kt` (only in the
  Huawei build; the Play build keeps `src/gms` and play-services-wearable).
  Same `app.tibyan/watch` channel and `push` call as Wear OS, so no Dart
  change and nothing edition-specific: the 1441 and 1405 editions push the
  same keys (their own page numbers), so both work identically.
- SDK: `com.huawei.hms:wearengine:5.0.3.300` from
  `https://developer.huawei.com/repo/` (added only when `TIBYAN_STORE=huawei`).
- Phone → watch only: one P2P message, JSON of the Wear OS `/tibyan/state`
  keys (`portion_/surah_/from_/to_<yyyy-MM-dd>` for the next 3 days,
  `progress`, `idle`, `tasbih_dhikr`, `tasbih_target`, `tasbih_stages`,
  `tasbih_stage_texts`). Small text only, a few hundred bytes.
- Nothing goes watch → phone. Wear Engine cannot deliver to a phone app
  that is not running, and Tibyan has no server by design (no accounts, no
  user data leaves the device), so there is no Internet route either. The
  watch misbaha counts on the watch and keeps its count in `@system.storage`;
  the phone's misbaha is separate. (Wear OS and Apple Watch still sync
  counts back; this is Huawei only.)
- The phone pushes when Tibyan opens (`WatchBridge` init resends the saved
  state) and whenever the khatma or dhikr changes. Wear Engine needs both
  apps active, so a push only lands while the watch app is open; the next
  open of either side catches up.
- Phone app not active: the watch shows the last state it received (kept in
  storage, 3 days of portions ahead, so «ورد اليوم» stays right for 3 days),
  and the misbaha works fully offline.
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
   (git-ignored). The watch only uses `P2pClient.registerReceiver`.
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
   apply, for the **phone app only** (`app.tibyan.tibyan`, Android app),
   permission «Basic device information» (device list + phone ↔ watch app
   messages); no notification, user status, sensor or SN permissions.
   Upload the filled «Data Permission and Usage Description» form and the
   scenario screens (`~/Desktop/هواوي/ساعة/wear-engine-form/`). The first
   application (two-way sync, Watch 4 / Fit 2) was rejected; this one is
   one-way and targets the latest lite wearables. Review: 1-2 weeks.
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
   the phone and a tasbih counter that works on the watch alone. No ads, no account."
