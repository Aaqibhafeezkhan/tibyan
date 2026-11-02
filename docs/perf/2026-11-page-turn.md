# Page-turn performance with fawasil (2026-11)

Branch `perf/page-turn-fasil`. Harness: `integration_test/page_turn_perf_test.dart`
(`flutter drive --profile`, `--dart-define=PERF_SET=phone|tablet|editions|index`).

## Setup and limits

- No physical iPhone/Android phone was connected. iOS simulator cannot run
  profile builds, so **no iOS numbers**. macOS profile was not used: it shares
  the owner's TestFlight app data (same bundle id) and the test rewrites
  bookmarks.
- Android emulator `Tibyan_PageTurn` (Pixel 7, API 35 arm64, host GPU, 60 Hz),
  profile build, Impeller (Android default). The Mac was heavily loaded by
  another agent's builds/emulator during runs (host CPU ~0% idle), so
  absolute numbers are inflated and noisy: the same "plain" case varies up to
  2x between runs. Read the **relative** differences between scenarios only.
- Each case: open page 50, 2 warm-up turns, then 6 measured fling turns.
  build/raster/total = avg/p90/p99 ms from `FrameTiming`; jank60 = frames with
  build or raster > 16.7 ms, jank120 > 8.3 ms.
- Not run (time): tablet two-page spread (`PERF_SET=tablet`), 1405/Shamarly
  (`PERF_SET=editions`, needs pack download). The harness supports both.

## Results: page turns (Android emulator, profile)

Before = `origin/main` (6d6a668); after = this branch's fixes.

| Scenario | Effect | Build before | Build after | Raster before | Raster after | jank60 before → after |
|---|---|---|---|---|---|---|
| plain | normal | 3.7/4.0/35 | 3.0/5.4/56 | 19.1/31/125 | 26.6/57/195 | 42% → 46% |
| plain | curl | 7.2/8.2/180 | 11.1/15/177 | 23.7/30/313 | 34.1/73/278 | 35% → 55% |
| plain | fade | 7.5/17/125 | 7.8/18/114 | 49.8/106/330 | 31.4/67/154 | 62% → 66% |
| active-tint | curl | 10.9/21/163 | 4.1/9.8/49 | 36.2/77/415 | 24.4/59/171 | 50% → 41% |
| active-tint | fold | 17.4/32/180 | 2.4/4.6/21 | 47.9/95/449 | 14.0/32/80 | 53% → 24% |
| active-ribbon | normal | 11.7/9.6/241 | 2.1/4.8/19 | 51.8/91/573 | 21.0/41/101 | 73% → 48% |
| active-ribbon | bend | 20.8/31/238 | 3.5/6.9/29 | 54.6/102/409 | 24.4/48/171 | 66% → 47% |
| active-ribbon | fold | 17.2/20/450 | 4.0/9.3/40 | 46.4/106/382 | 19.6/39/87 | 63% → 45% |
| active-ribbon | fade | 24.8/51/313 | 5.4/13/84 | 116.0/281/1093 | 38.7/86/239 | 92% → 72% |
| active-tab | normal | 10.0/18/206 | 4.1/8.1/49 | 69.9/155/767 | 31.3/69/185 | 75% → 57% |
| active-tab | curl | 37.1/77/749 | 5.8/15/47 | 95.2/177/787 | 28.6/60/175 | 89% → 58% |
| active-tab | bend | 14.5/24/234 | 7.0/19/80 | 53.0/116/448 | 31.5/71/199 | 62% → 57% |
| active-tab | fold | 32.7/33/220 | 3.3/7.4/28 | 56.1/130/328 | 20.7/50/107 | 67% → 41% |
| ghost-ribbon | all 5 | 1.4–2.7 avg | 1.3–2.1 avg | 14–21 avg | 13.5–17 avg | 29–47% → 29–39% |
| ghost-tab | all 5 | 1.3–2.1 avg | 0.6–1.5 avg* | 14–19 avg | 12–14 avg* | 29–48% → 24–32%* |
| memorize | all 5 | 1.4–12 avg | 0.3–0.9 avg | 18–44 avg | 11–15 avg | 32–55% → 24–37% |

\* except one ghost-tab/fold outlier run (host stall, p99 > 1 s).
Full raw lines (all 35 cases × before/after, with total and jank120):
see the appendix.

### Findings

1. **An active fasil on the page was the dominant cost**: before the fix,
   active ribbon/tab turns cost 2–5x the plain page's build and 2–4x its
   raster (e.g. tab+curl build 37 ms vs 7 ms). After the fix they are close
   to the plain page.
2. **Ghost (faded) marks cost almost nothing** (build ≈ 1–2 ms): they sit
   outside the pager and do not repaint during a turn. They did use two
   `saveLayer`s each (Opacity + ColorFiltered).
3. Plain-page jank is mostly emulator/host bound (software path, loaded host);
   page art is already baked to an image (`mushaf_page.dart` `_bakeArt`), so
   no SVG re-parse per frame was seen.
4. Fade and 3D-curl are the most raster-heavy effects (full-page Opacity
   layer in `page_turn_effect.dart:553`; curl shader + snapshot).

### Fixes on this branch (low risk)

- `fasil_bookmarks.dart` FasilPageLayer / FasilSpineLayer: each placed fasil
  wrapped in its own `RepaintBoundary`, so the ribbon cloth, tab SVG ornament,
  shadow and label are not repainted with the page each turn frame.
- Faded marks (ribbon and tab): `Opacity(.6)` + `ColorFiltered` merged into a
  single `ColorFilter.matrix` with alpha 0.6: one layer instead of two, same
  pixels.
- Tab shadow clipping (owner bug, screenshot 18): the folded tab and the
  side-placed tab clipped with a plain `ClipRect`, cutting the drop shadow at
  the sides and foot. They now clip only above the top edge (`_BelowTop`),
  adding no layer.

### Proposed next fixes (ranked)

1. Fade effect: draw the incoming page from its snapshot with
   `RawImage(opacity:)` instead of `Opacity` over the live page
   (`page_turn_effect.dart:553`), removing a full-screen saveLayer per frame.
2. `mushaf_screen.dart:790` `fawasilOn(pg)` builds a new list each build, so
   `FasilPageLayer` always rebuilds; memoize per page.
3. Precache neighbour pages' snapshots for curl/bend before the first drag
   (first-turn spikes in p99).
4. Index → mushaf: `MushafScreen` is keyed by the full URI
   (`app_router.dart:347`), so every index jump rebuilds the whole reader
   state; reuse the screen and jump the controller instead.

## Round 2 (branch `perf/page-turn-fasil-2`): all proposed fixes

Method: each fix has a debug switch back to the old way, and the harness
runs old and new **interleaved, case by case, in the same run**
(`--dart-define=PERF_AB=fade|memo|precache|reuse|artcache`,
`PERF_REPEAT=5`, `PERF_ONLY`, `PERF_EFFECTS`). Values below are **medians
of 5 runs** (build/raster avg/p90/p99 ms; jank60 = % frames > 16.7 ms).
The host was heavily loaded by other agents (iOS simulator, flutter test;
load average up to 190) during the Pixel 7 runs, so Pixel 7 absolutes are
inflated; old/new pairs ran minutes apart under the same load. The low-end
AVD run happened on a quiet host (load ~2).

Devices: `Tibyan_PageTurn` (Pixel 7 profile, API 35, 1080x2400, 4 GB);
`Tibyan_PageTurn_Low` (new: API 33, 2 GB RAM, 4 cores, 720x1600, 280 dpi).
No physical Android phone was connected. iOS not measured (owner: not needed).

| # | Fix | Device | Case | Old | New |
|---|---|---|---|---|---|
| 1 | Fade from snapshot (no Opacity layer) | Pixel 7 | plain fade raster / jank60 | 24.6/63/189, 34.9% | 23.6/61/190, 28.6% |
| 1 | | Pixel 7 | active-ribbon fade | 26.7/48/147, 56.0% | 27.9/59/176, 46.6% |
| 1 | | Pixel 7 | active-tab fade | 24.5/44/180, 49.0% | 26.3/53/204, 46.9% |
| 1 | | Low-end | plain fade | 4.5/16.3/26.0, 7.6% | 3.8/15.3/23.3, 6.5% |
| 1 | | Low-end | active-ribbon fade | 8.1/17.3/27.5, 16.8% | 6.3/16.7/22.3, 10.2% |
| 1 | | Low-end | active-tab fade | 8.0/17.3/23.6, 15.0% | 7.0/17.1/22.8, 12.7% |
| 2 | Memoized `fawasilOn` + reused bookmark widgets | Pixel 7 | active-ribbon normal / curl jank60 | 50.2% / 42.5% | 49.0% / 41.7% |
| 2 | | Pixel 7 | active-tab normal / curl jank60 | 44.1% / 41.6% | 43.6% / 43.2% |
| 3 | Snapshot before first drag (bounded wait), shader warm-up, spread halves ahead | Pixel 7 | **first turn** raster max, plain curl | 173 | 123 |
| 3 | | Pixel 7 | first turn raster max, active-ribbon curl / fold | 187 / 176 | 127 / 144 |
| 3 | | Pixel 7 | first turn raster max, plain bend / active-ribbon bend | 148 / 130 | 156 / 181 |
| 3 | | Pixel 7 | steady jank60 plain bend / active-ribbon fold | 37.9% / 40.3% | 33.2% / 35.9% |
| 4 | Index jump reuses MushafScreen | Pixel 7 | index ttff (nomarks / ribbon / tab) | 226 / 246 / 220 ms | 126 / 143 / 122 ms |
| 4 | | Pixel 7 | index settle (nomarks / ribbon / tab) | 1364 / 1626 / 1635 ms | 1235 / 1411 / 1314 ms |
| 5 | Shared cache of the last 4 baked pages | Pixel 7 | home A ornate+fasil: settle, raster p90, raster sum | 1987 ms, 201, 1137 ms | 897 ms, 40, 690 ms |
| 5 | | Pixel 7 | home B plain+fasil | 1737 ms, 168, 853 ms | 839 ms, 35, 480 ms |
| 5 | | Pixel 7 | home C plain, no fasil | 1845 ms, 171, 808 ms | 770 ms, 36, 364 ms |

Reading:
1. **Fade**: fewer janky frames everywhere (low-end active-ribbon 16.8% → 10.2%);
   raster avg down on the low-end AVD; on the loaded Pixel 7 run raster is
   within noise. Visuals: same pixels (the snapshot is taken at the device
   pixel ratio; it falls back to the old Opacity until the snapshot exists).
2. **Memo**: neutral in frame times: the screen rarely rebuilds during a
   turn (build avg 2–3 ms). It removes needless bookmark rebuilds when it
   does (unit test `test/mushaf/fasil_layer_reuse_test.dart`). Kept: tiny,
   no visual change.
3. **Precache**: first-turn worst raster frame −30–50 ms for curl/fold;
   bend mixed (within noise).
4. **Index reuse**: time to the target page's first frame **−45%**; settle
   −10–20%. The rest is the index route's pop transition. Deep links with a
   verse (`s`/`a`), hifz, listen and memorize still open a new screen
   (`mushafSessionOf` in `app_router.dart`); tests in
   `test/flows/mushaf_index_jump_test.dart`. The home card opens `/mushaf`
   from `/` where no MushafScreen exists, so reuse cannot apply there;
   fix 5 targets it instead.
5. **Home «متابعة القراءة» ablation** (before the cache, Pixel 7, medians):
   A ornate (hijazi) + 2 fawasil: ttff 161 ms, settle 2188 ms, raster
   p90 263 ms, raster sum 1233 ms; B plain + fawasil: 238 / 2107 / 161 / 1006;
   C plain, no fasil: 190 / 1971 / 192 / 950. Breakdown: build sum is only
   90–140 ms; **raster dominates**, and it is the page bake (thousands of
   SVG paths into an image) of the target page and its two neighbours
   during the entrance; the ornate frame adds ~20% raster, fawasil ~5%.
   Fix: the last 4 baked pages are shared across MushafPage instances
   (`MushafPage._baked`, image clones, LRU, ~30 MB max at 1080p), so
   reopening the page read last blits it. **Settle −55–60%, raster p90
   −80%.** A cold first open (page never baked this session) is unchanged.

### Still pending after round 2
Done in round 3 (below), except iOS (owner: not needed).

## Round 3 (branch `perf/measure-round3`, main at c50bb695): Android, quiet host

Code under test: `main` with all round-2 fixes except fix 2 (memo), which
the margin-ribbon layout replaced, plus per-fasil looks and margin ribbons.
Setup: profile builds, Impeller, emulators with `-gpu host` (Apple M4 GPU)
and no audio; host load ~2.5 (no other builds). **Medians of 5 runs.**
Format: raster avg/p90/p99 ms; jank60 = % of frames over 16.7 ms (page
turns) or a frame count of ~55 (index/home). Build avg stays ≤ 1 ms
everywhere, so it is left out.

Note: a first low-end run with `-no-window` fell back to SwiftShader
(software GPU) and showed 55–79% jank; it was discarded. Always pass
`-gpu host`.

### Low-end AVD `Tibyan_PageTurn_Low` (API 33, 2 GB, 4 cores, 720×1600)

Page turns (merged code), raster p90 ms / jank60 %:

| Scenario | normal | curl | bend | fold | fade |
|---|---|---|---|---|---|
| plain | 15.3 / 6.3 | 16.7 / 10.1 | 17.0 / 12.3 | 15.2 / 5.4 | 16.9 / 12.0 |
| active tint | 16.4 / 8.0 | 16.1 / 6.6 | 16.1 / 7.1 | 6.3 / 4.4 | 5.2 / 3.5 |
| active ribbon | 15.4 / 5.2 | 16.1 / 6.7 | 16.1 / 7.8 | 13.5 / 5.3 | 17.1 / 12.7 |
| active tab | 15.2 / 6.8 | 16.1 / 7.3 | 16.9 / 12.9 | 16.8 / 11.7 | 13.9 / 5.4 |
| ghost ribbon | 16.4 / 8.4 | 4.7 / 2.4 | 6.5 / 4.3 | 5.6 / 4.8 | 15.9 / 6.0 |
| ghost tab | 13.7 / 4.6 | 4.5 / 0.0 | 14.6 / 4.7 | 15.7 / 7.4 | 14.3 / 5.0 |
| memorize | 12.4 / 6.3 | 4.9 / 1.6 | 15.4 / 4.9 | 14.9 / 5.6 | 5.1 / 4.7 |

Worst case 12.9% janky, p90 17.1 ms, p99 ≤ 28.7 ms. No page-turn scenario
reaches the heavy-jank bar (> 25% or p90 > 30 ms), so no new fix.

Fix A/B on the low-end AVD (old → new):

| Fix | Case | raster p90 | jank60 | first-turn raster max |
|---|---|---|---|---|
| 1 fade snapshot | plain fade | 16.6 → 7.8 | 10.0% → 5.6% | 22.7 → 8.4 |
| | active-ribbon fade | 16.5 → 16.5 | 8.7% → 9.6% | 9.5 → 7.7 |
| | active-tab fade | 17.2 → 15.8 | 14.2% → 7.9% | 8.8 → 17.7 |
| 3 precache | plain curl / bend / fold | 16.1→6.1 / 14.3→4.4 / 6.4→10.9 | 7.3→3.8 / 6.2→0.6 / 5.1→6.8 | ≈ same (8–10) |
| | active-ribbon curl / bend / fold | 16.1→12.8 / 15.8→7.4 / 6.8→11.9 | 8.3→4.5 / 7.1→4.5 / 5.9→5.2 | ≈ same (7–20) |

Fix 4, index jump reuse (median over 5 effects): ttff no marks 55 → 39 ms,
ribbon 56 → 40, tab 55 → 40 (**−28%**); settle −3 to −19%. Frames during
the jump: raster p90 27–35 ms, 11–16 janky of ~55 (20–29%), same before
and after: this is the cold bake of the target page and its neighbours plus
the route transition, not the reuse path. Pixel 7 shows the same profile
(p90 31–42 ms), so it is the bake cost, not a low-end weakness. Possible
follow-up (not done, medium risk): defer neighbour bakes until the route
transition ends.

### Home «متابعة القراءة» ablation (fix 5 A/B = cold vs warm)

`~old` disables the shared baked-page cache, i.e. a cold open (page never
baked); `~new` reopens the page read last (warm).

| Device | Case | ttff | settle cold → warm | raster p90 cold → warm | raster sum cold → warm | janky frames |
|---|---|---|---|---|---|---|
| Low-end | A ornate + fasil | 95 / 85 | 434 → 233 | 39.7 → 11.2 | 218 → 94 | 5 → 0 |
| Low-end | B plain + fasil | 84 / 86 | 397 → 233 | 33.2 → 7.0 | 173 → 73 | 3 → 0 |
| Low-end | C plain, no fasil | 89 / 86 | 353 → 218 | 31.3 → 5.2 | 150 → 39 | 4 → 0 |
| Pixel 7 | A ornate + fasil | 55 / 59 | 517 → 251 | 41.4 → 16.9 | 292 → 169 | 6 → 2 |
| Pixel 7 | B plain + fasil | 55 / 56 | 466 → 246 | 38.0 → 15.8 | 233 → 150 | 4 → 0 |
| Pixel 7 | C plain, no fasil | 54 / 54 | 416 → 218 | 38.9 → 5.3 | 190 → 73 | 4 → 0 |

Cold: the ornate frame adds ~25% raster over plain, fawasil ~15%. Warm
opens settle **~45% faster** with raster p90 −60–85%.

### Tablet two-page spread (`Tibyan_PageTurn_Tab`, 2560×1600)

Raster p90 ms / jank60 %:

| Scenario | normal | curl | bend | fold | fade |
|---|---|---|---|---|---|
| plain | 11.3 / 6.9 | 16.7 / 10.6 | 6.6 / 3.3 | 16.6 / 9.5 | 16.9 / 14.0 |
| active tint | 8.5 / 6.0 | 5.4 / 3.3 | 11.2 / 4.6 | 16.1 / 8.1 | 16.8 / 12.4 |
| active ribbon | 14.8 / 5.9 | 16.9 / 12.9 | 16.4 / 8.3 | 16.9 / 13.1 | 17.1 / 15.6 |
| active tab | 16.7 / 10.6 | 17.0 / 13.6 | 15.7 / 7.2 | 17.0 / 13.4 | 16.6 / 8.7 |
| ghost ribbon | 16.9 / 12.9 | 16.8 / 11.9 | 16.6 / 9.3 | 16.3 / 8.9 | 17.0 / 14.2 |
| ghost tab | 16.6 / 8.6 | 16.6 / 9.9 | 16.5 / 8.0 | 16.3 / 8.2 | 16.8 / 12.4 |

Worst 15.6% (active ribbon fade); p99 ≤ 28.3 ms. Fine.

### Editions on Pixel 7 (packs downloaded in the emulator app)

Raster p90 ms / jank60 %:

| Scenario | normal | curl | bend | fold | fade |
|---|---|---|---|---|---|
| 1405 plain | 6.9 / 5.8 | 4.7 / 0.4 | 16.4 / 7.8 | 13.2 / 5.3 | 16.3 / 7.4 |
| 1405 active ribbon | 12.9 / 4.5 | 15.7 / 6.1 | 16.1 / 6.6 | 13.5 / 5.1 | 15.9 / 5.7 |
| Shamarly plain | 15.3 / 5.5 | 5.5 / 4.3 | 7.6 / 4.6 | 4.2 / 0.6 | 4.9 / 2.2 |
| Shamarly active ribbon | 7.1 / 5.2 | 4.8 / 0.6 | 7.6 / 5.5 | 16.1 / 6.9 | 11.6 / 4.3 |

Both PNG editions turn as smoothly as 1441 (≤ 7.8% janky).

### Pixel 7 key numbers, quiet host (`Tibyan_PageTurn`)

Raster p90 ms / jank60 % (first-turn raster max in brackets):

| Scenario | normal | curl | bend | fold | fade |
|---|---|---|---|---|---|
| plain | 14.3 / 5.4 (7) | 6.6 / 5.2 (21) | 4.7 / 0.8 (16) | 4.9 / 1.6 (21) | 9.8 / 5.5 (16) |
| active ribbon | 6.2 / 2.9 (8) | 15.3 / 4.6 (18) | 6.4 / 4.8 (18) | 4.4 / 0.6 (18) | 15.1 / 5.5 (16) |
| active tab | 7.0 / 5.3 (21) | 15.1 / 5.3 (17) | 14.9 / 5.4 (16) | 6.9 / 4.9 (16) | 15.5 / 5.5 (16) |

Index jump ttff 36–42 ms, settle 280–400 ms. The round-1/2 Pixel 7 numbers
(jank 35–75%, first-turn max 120–180 ms) were inflated by the loaded host;
on a quiet host every turn is ≤ 5.5% janky and first turns ≤ 21 ms.

### Round 3 conclusions
1. No page-turn scenario on any device crosses the heavy-jank bar; no code
   change this round. Fix 2 (memo) stays removed: margin-layout numbers do
   not need it.
2. Remaining cost: the cold bake on navigation (index jump, cold home
   open): p90 raster 30–40 ms over ~0.3 s. Candidate follow-up: defer
   neighbour bakes until after the route transition.

## Round 5 (branch `perf/startup`, main at b7d42e02): cold start, instant continue/index

Low-end AVD `Tibyan_PageTurn_Low` (API 33, 2 GB, 720×1600), profile build,
`-gpu host -no-audio`, one emulator, no test suite running alongside.
Raw lines: `docs/perf/raw/round5-*.txt`. The emulator is noisy (±20%
between batches); A/B runs alternate old and new in one session.

### Cold start

Measured with `adb shell am start -W` (TotalTime) after `force-stop` and
`drop_caches`, 2 discarded warm-ups after each install, plus `STARTUP`
stage marks (new, PROF builds only: `lib/core/perf/startup_marks.dart`; ms
from the Dart binding). Medians of 10 (two alternating batches of 5).

| Build | TotalTime | Dart first frame | home first frame |
|---|---|---|---|
| main (baseline) | 3.88 s | 1.49 s | 2.27 s |
| audio setup after runApp + theme JSON read in parallel | 3.70 s | ≈ same | 2.17 s |

The tried changes moved the wait, not the work: the first platform call
after them (SharedPreferences) waited the same ~1.1 s. Within the noise,
so **both were reverted**; only the stage marks are kept.

Where the time goes (Perfetto trace, one cold start):

| Phase (Android main thread) | ms | Ours? |
|---|---|---|
| `bindApplication`: opening the dex files of the 250 MB fat APK (21 dex) | 600 of 862 | build: a per-ABI split / AAB (Play already splits) and a baseline profile would cut it |
| WorkManager initializer (androidx Startup) | 89 | plugin |
| `performCreate` MainActivity, engine + plugin registration | 438 | mostly engine |
| first `traversal`: main thread asleep while the raster thread sets up Impeller **GLES** (72 `ReactorGLES::React`, 856 ms) | 957 | emulator: no Vulkan on this AVD, so Impeller falls back to GLES through the host GL translator; real devices use Vulkan |
| Dart `main()` until `runApp` (theme, flags, prefs, content.db, providers) | < 40 of own work | yes, already small |
| splash animation (fixed 960 ms by design) | 800–900 after first frame | design choice, not changed |

Conclusion: on this AVD, Dart-side startup is not the bottleneck. The
two real levers are build-side (ABI split + baseline profile, ~0.5 s) and
the splash length (a product call). Neither changed here.

### «متابعة القراءة» from home (harness now taps the card's button)

`PERF_AB=tap`: `~old` = route only (as Round 3 measured), `~new` = the card
tapped (snapshot armed, grow transition). `first` = the first open of that
look after launch (home prewarm ran, 4 s on home); `again` = medians of 4.

| Case | ttff old → new | settle old → new | raster p90 old → new |
|---|---|---|---|
| A ornate + fasil, first | 234 → 107 | **2748 → 211** | **413 → 32** |
| A ornate + fasil, again | 130 → 126 | 599 → 644 | 27 → 37 |
| B plain + fasil, first | 198 → 165 | 350 → 299 | 158 → 23 |
| B plain + fasil, again | 156 → 117 | 322 → 387 | 25 → 26 |
| C plain, first | 91 → 60 | 224 → 215 | 16 → 20 |
| C plain, again | 144 → 182 | 308 → 349 | 18 → 17 |

The win is the first open after launch: the ornate page no longer bakes
on the tap (settle −92%, raster p90 −92%). Repeat opens are a wash within
the noise. Versus Round 3 warm (ttff 85–86, settle 218–233): repeat opens
here settle 300–650 ms, in **both** paths, so it is this session's host
(not the new transition); recheck on a quiet host before calling it a
regression.

### Index jump (harness now sends the row's touch-down 100 ms before the tap)

`PERF_AB=touch`: `~old` = no touch-down, `~new` = `IndexJumpWarmer`
warmed the page first. Medians over the 5 page-turn effects (3 targets
each); jank = frames over 16.7 ms of ~55.

| Case | ttff old → new | settle old → new | raster p90 old → new | jank old → new |
|---|---|---|---|---|
| no marks | 92 → **56** | 306 → 327 | 66 → 60 | 12 → 12 |
| marks + ribbon | 73 → 63 | 562 → 550 | 96 → 79 | 23 → 24 |
| marks + tab | 77 → 68 | 536 → 532 | 79 → 79 | 20 → 26 |

The warm cuts ttff 12–39%; settle and jank are unchanged (the route
transition and neighbour bakes dominate, as in Round 3). Against Round 3
(ttff 39–40, 11–16 janky) both paths are slower in this session, the
marks cases most; the same host-noise caveat applies, and the old path
(no warm) moved as much as the new one, so the warm is not the cause.

### Checks
- Prewarm/warm skip only under `flutter test` (`FLUTTER_TEST` in the
  host environment); on the device under `flutter drive` they run (the
  first-open numbers above show it).
- No code change to the app beyond the PROF-only stage marks.

### Still open
1. ABI split for side-loaded APKs and a baseline profile: ~0.5 s of the
   1.0 s `bindApplication`.
2. Splash length (960 ms fixed): the largest cut left, a design decision.
3. ~~Re-measure index/continue repeat opens~~: done in «Round 5b», host load.
4. Neighbour bakes during the index route transition (Round 3 follow-up).

## Round 5b: host load or regression? (main bf2873f9 vs Round 3 416f9347)

Same session, same AVD (`Tibyan_PageTurn_Low`, `-gpu host -no-audio`, one
emulator), profile APKs built **before** measuring (`--use-application-binary`),
order main/r3/main/r3, each run started at 1-min load < 3.0 (2.7–3.0;
MetaTrader held ~1 core all session). `PERF_REPEAT=5`, two passes, medians.
Each build runs its own harness: main with `PERF_AB=tap|touch` gives `~old`
(the Round 3 path) and `~new`; r3 has no A/B. Raw: `docs/perf/raw/round5b-*.txt`.

Home «متابعة القراءة», repeat opens (`again`, 8 runs), ttff / settle / raster p90 ms:

| Case | r3 | main ~old | main ~new |
|---|---|---|---|
| A ornate + fasil | 259 / 890 / 41 | 232 / 503 / 43 | 219 / 626 / 54 |
| B plain + fasil | 206 / 924 / 34 | 215 / 411 / 37 | 130 / 466 / 33 |
| C plain | 235 / 754 / 25 | 245 / 551 / 29 | 234 / 374 / 26 |

First open after launch, settle: A 4675 (r3) / 3715 (~old) / 841 (~new); B 1795 / 778 / 482.

Index jump (5 effects × 5 runs × 2 passes), ttff / settle / raster p90 ms / janky frames:

| Case | r3 | main ~old | main ~new |
|---|---|---|---|
| no marks | 151 / 1277 / 130 / 21.5 | 134 / 353 / 42 / 9 | 90 / 322 / 36 / 12 |
| marks + ribbon | 162 / 1291 / 133 / 37 | 141 / 691 / 110 / 22 | 97 / 660 / 108 / 25 |
| marks + tab | 153 / 1277 / 138 / 41 | 154 / 799 / 119 / 25 | 93 / 607 / 104 / 27 |

The two passes agree within ~15%.

**Verdict: host, not code.** On the same host, the Round 3 build is slower
than main on every metric (index settle 3.6× slower, repeat-open settle 1.4–2.2×),
and it is itself 3–4× slower than its own Round 3 figures (index ttff 39–40,
settle 218–233). So the whole emulator is slower than on the Round 3 day;
nothing since Round 3 regressed. No bisect, no fix. Compare runs only
within one session.

## Index → mushaf navigation

What a tap on a surah does: `versePageProvider` lookup, then
`router.go(mushafLocation(page))` from `/mushaf/index`. Three targets
(pages 50, 293, 440), per page-turn setting. ttff = until the target
`MushafPage` is in the tree and one frame pumped; settle = until no
transient callbacks for 3 frames (includes chrome animations).

Before (avg/p90 ms; jank = frames > 16.7 ms of ~55):

| Case | lookup | ttff | settle | build avg/p90/p99 | raster avg/p90/p99 |
|---|---|---|---|---|---|
| no marks (5 effects) | 0.2–11 | 164–231 | 1540–2080 | 6–14 / 15–39 / 33–158 | 31–47 / 110–154 / 172–600 |
| marks + ribbon | 0.1–1.3 | 148–235 | 1080–1630 | 5–9 / 13–19 / 22–61 | 38–67 / 110–144 / 147–437 |
| marks + tab | 0.2–0.8 | 141–436 | 1300–2730 | 6–17 / 18–31 / 33–262 | 39–96 / 108–215 / 187–783 |

The page-turn setting does not change the route transition. Fawasil add
little to ttff except one tab/curl outlier. The bookmark lookup is not on the
critical path (< 1 ms after warm-up). The cost is the route transition plus
rebuilding the whole reader (see proposed fix 4). After-fix index numbers:
see appendix (the run overlapped another agent's heavy build, so they are not
comparable).

## Not done (needs follow-up)

- iOS numbers (owner: not needed). Tablet, editions and home ablation: done
  in «Round 3».
- Owner feature requests forwarded mid-task: 8-fawasil limit with move sheet,
  index fawasil management tab, per-fasil look/material/colour overrides.
  These are features, not perf work; they need their own branch.

## Appendix: raw lines

The after-fix index run hit a 10 s timeout on one target while the host was
saturated; only its partial lines are listed.
### pt_before
    plain normal frames=405 build=3.7/4.0/35.3 raster=19.1/30.6/125.2 total=46.3/77.9/481.3 jank60=42.0% jank120=74.1%
    plain curl frames=367 build=7.2/8.2/180.0 raster=23.7/29.5/313.0 total=143.6/132.3/5746.6 jank60=35.1% jank120=64.3%
    plain bend frames=392 build=4.3/6.1/66.9 raster=21.6/24.1/268.4 total=58.8/104.1/1268.5 jank60=39.0% jank120=81.4%
    plain fold frames=284 build=7.3/10.4/116.0 raster=24.0/60.3/164.5 total=73.7/146.9/805.0 jank60=39.4% jank120=68.0%
    plain fade frames=220 build=7.5/16.7/125.4 raster=49.8/106.2/330.2 total=107.8/245.4/611.6 jank60=61.8% jank120=85.0%
    active-tint normal frames=176 build=93.3/122.8/2341.2 raster=286.2/267.4/3688.7 total=748.4/1022.5/12680.9 jank60=72.7% jank120=90.3%
    active-tint curl frames=278 build=10.9/20.9/162.9 raster=36.2/76.9/415.3 total=98.4/209.0/1159.9 jank60=50.0% jank120=80.2%
    active-tint bend frames=290 build=11.2/19.6/201.4 raster=46.7/59.7/1195.3 total=152.4/255.5/2619.5 jank60=52.4% jank120=76.9%
    active-tint fold frames=257 build=17.4/32.3/179.9 raster=47.9/94.8/448.9 total=154.3/245.9/2952.0 jank60=53.3% jank120=73.9%
    active-tint fade frames=238 build=7.4/11.1/131.2 raster=43.5/95.0/354.3 total=100.8/224.9/918.9 jank60=49.6% jank120=78.6%
    active-ribbon normal frames=250 build=11.7/9.6/240.6 raster=51.8/91.2/572.7 total=115.0/239.1/1221.1 jank60=73.2% jank120=93.2%
    active-ribbon curl frames=246 build=18.6/33.6/165.1 raster=53.8/111.1/591.7 total=152.0/327.2/1165.6 jank60=65.0% jank120=83.3%
    active-ribbon bend frames=237 build=20.8/31.1/237.6 raster=54.6/101.8/409.3 total=130.1/286.4/640.6 jank60=66.2% jank120=83.5%
    active-ribbon fold frames=233 build=17.2/19.9/450.4 raster=46.4/106.1/382.3 total=116.7/268.8/711.6 jank60=62.7% jank120=84.5%
    active-ribbon fade frames=191 build=24.8/50.7/313.4 raster=116.0/281.2/1092.6 total=256.0/672.2/1816.9 jank60=92.1% jank120=97.9%
    active-tab normal frames=258 build=10.0/18.2/205.9 raster=69.9/154.6/767.0 total=164.8/445.3/1597.5 jank60=74.8% jank120=96.1%
    active-tab curl frames=177 build=37.1/76.6/748.6 raster=95.2/176.5/787.4 total=256.4/579.6/2510.3 jank60=89.3% jank120=96.6%
    active-tab bend frames=246 build=14.5/24.2/233.8 raster=53.0/116.3/448.4 total=167.0/329.0/2486.0 jank60=61.8% jank120=87.4%
    active-tab fold frames=267 build=32.7/33.3/219.5 raster=56.1/130.0/328.3 total=159.0/289.0/1728.3 jank60=67.4% jank120=87.3%
    active-tab fade frames=298 build=2.8/5.7/29.7 raster=20.8/44.5/102.1 total=49.7/91.3/247.2 jank60=41.3% jank120=81.5%
    ghost-ribbon normal frames=396 build=1.9/3.2/33.2 raster=20.8/39.3/95.5 total=39.2/86.6/283.0 jank60=47.2% jank120=83.8%
    ghost-ribbon curl frames=457 build=1.4/2.6/10.5 raster=15.7/20.0/113.3 total=33.6/36.2/335.1 jank60=28.9% jank120=70.2%
    ghost-ribbon bend frames=405 build=2.7/4.4/23.2 raster=20.7/31.5/107.4 total=45.6/89.0/447.1 jank60=43.2% jank120=93.6%
    ghost-ribbon fold frames=409 build=2.2/3.0/23.5 raster=16.0/27.9/69.2 total=31.4/60.5/171.8 jank60=36.7% jank120=70.9%
    ghost-ribbon fade frames=467 build=1.4/2.5/12.6 raster=14.2/20.4/53.6 total=23.4/33.5/131.9 jank60=33.0% jank120=73.9%
    ghost-tab normal frames=425 build=1.6/3.0/16.2 raster=18.6/27.1/62.4 total=34.6/55.5/258.9 jank60=48.0% jank120=94.6%
    ghost-tab curl frames=446 build=2.1/3.7/19.8 raster=17.4/22.3/82.7 total=35.3/41.3/325.3 jank60=37.4% jank120=87.7%
    ghost-tab bend frames=458 build=1.3/2.4/8.0 raster=16.6/18.2/82.4 total=30.2/32.4/303.7 jank60=33.6% jank120=87.6%
    ghost-tab fold frames=483 build=1.4/2.8/9.2 raster=13.6/18.6/30.5 total=22.5/29.5/108.3 jank60=28.8% jank120=73.9%
    ghost-tab fade frames=336 build=1.7/3.5/13.4 raster=19.3/32.9/62.8 total=39.8/73.6/148.3 jank60=44.9% jank120=87.8%
    memorize normal frames=236 build=12.1/11.2/161.0 raster=44.0/107.8/291.7 total=109.7/198.2/1132.3 jank60=55.1% jank120=73.7%
    memorize curl frames=312 build=2.2/4.5/19.7 raster=24.5/44.3/120.6 total=67.8/110.3/500.5 jank60=37.2% jank120=66.3%
    memorize bend frames=340 build=1.5/2.9/11.9 raster=18.4/41.9/96.3 total=48.4/98.1/364.0 jank60=32.4% jank120=64.7%
    memorize fold frames=306 build=5.8/6.7/94.8 raster=21.1/40.9/99.5 total=51.1/89.1/253.4 jank60=45.8% jank120=85.0%
    memorize fade frames=363 build=1.4/2.2/14.3 raster=18.4/26.5/84.9 total=38.8/78.4/111.2 jank60=39.7% jank120=85.4%
### pt_after
    plain normal frames=295 build=3.0/5.4/55.9 raster=26.6/57.0/195.3 total=64.3/139.5/567.5 jank60=45.8% jank120=70.8%
    plain curl frames=263 build=11.1/14.8/176.5 raster=34.1/72.6/277.5 total=105.5/229.0/1171.4 jank60=54.8% jank120=81.0%
    plain bend frames=240 build=8.9/17.3/130.9 raster=41.1/87.1/414.6 total=122.9/266.2/1432.0 jank60=60.8% jank120=82.1%
    plain fold frames=224 build=16.6/31.0/257.0 raster=43.7/103.5/306.5 total=108.5/269.7/595.9 jank60=64.7% jank120=86.6%
    plain fade frames=246 build=7.8/17.6/113.8 raster=31.4/67.1/154.2 total=83.5/156.4/705.3 jank60=66.3% jank120=89.0%
    active-tint normal frames=270 build=5.8/11.3/144.9 raster=27.4/65.8/149.6 total=77.8/148.6/688.3 jank60=53.0% jank120=80.7%
    active-tint curl frames=292 build=4.1/9.8/49.0 raster=24.4/58.5/170.7 total=76.3/174.5/738.2 jank60=41.1% jank120=66.1%
    active-tint bend frames=278 build=6.2/19.0/69.5 raster=28.2/66.0/267.0 total=82.0/165.8/668.3 jank60=45.0% jank120=71.6%
    active-tint fold frames=310 build=2.4/4.6/20.9 raster=14.0/31.8/80.1 total=43.4/83.1/241.3 jank60=23.5% jank120=51.0%
    active-tint fade frames=322 build=2.3/4.0/18.4 raster=16.7/33.3/90.5 total=42.1/77.8/217.4 jank60=29.2% jank120=69.6%
    active-ribbon normal frames=312 build=2.1/4.8/19.3 raster=21.0/41.4/101.0 total=50.1/90.8/248.9 jank60=48.4% jank120=82.7%
    active-ribbon curl frames=242 build=10.9/25.9/125.5 raster=48.2/94.5/410.4 total=129.2/314.6/1149.7 jank60=66.1% jank120=89.7%
    active-ribbon bend frames=321 build=3.5/6.9/29.2 raster=24.4/47.5/171.0 total=67.5/113.2/711.4 jank60=47.4% jank120=76.0%
    active-ribbon fold frames=303 build=4.0/9.3/39.6 raster=19.6/39.4/87.1 total=53.3/87.7/346.9 jank60=45.2% jank120=79.2%
    active-ribbon fade frames=280 build=5.4/13.2/84.2 raster=38.7/85.8/238.6 total=94.4/168.5/481.2 jank60=71.8% jank120=94.6%
    active-tab normal frames=277 build=4.1/8.1/49.0 raster=31.3/68.5/184.5 total=74.5/142.9/393.1 jank60=57.4% jank120=91.0%
    active-tab curl frames=303 build=5.8/14.7/47.1 raster=28.6/60.1/174.5 total=79.8/153.4/581.8 jank60=57.8% jank120=83.8%
    active-tab bend frames=270 build=7.0/18.7/79.7 raster=31.5/70.7/199.0 total=92.8/230.5/935.8 jank60=57.4% jank120=84.1%
    active-tab fold frames=322 build=3.3/7.4/28.0 raster=20.7/49.7/106.9 total=51.3/95.6/276.4 jank60=41.3% jank120=74.5%
    active-tab fade frames=342 build=2.1/3.9/18.7 raster=20.3/40.9/108.1 total=43.9/73.5/224.1 jank60=43.9% jank120=84.2%
    ghost-ribbon normal frames=417 build=1.3/1.8/16.8 raster=15.6/25.2/87.4 total=28.5/54.2/196.5 jank60=31.7% jank120=70.5%
    ghost-ribbon curl frames=455 build=2.0/3.5/11.2 raster=16.9/20.4/98.6 total=33.3/46.9/383.0 jank60=33.0% jank120=74.9%
    ghost-ribbon bend frames=452 build=1.8/3.0/10.5 raster=17.0/19.5/105.4 total=34.8/33.9/416.6 jank60=34.5% jank120=80.1%
    ghost-ribbon fold frames=481 build=1.5/2.6/11.3 raster=13.5/18.7/28.8 total=21.6/27.1/124.7 jank60=28.9% jank120=74.6%
    ghost-ribbon fade frames=438 build=2.1/2.7/11.6 raster=16.1/20.9/53.1 total=26.8/37.5/156.1 jank60=38.6% jank120=79.7%
    ghost-tab normal frames=477 build=0.6/1.2/6.5 raster=13.6/18.2/34.8 total=19.7/28.1/80.2 jank60=31.7% jank120=70.6%
    ghost-tab curl frames=473 build=1.5/2.8/9.8 raster=13.1/18.3/71.9 total=24.0/28.1/276.9 jank60=23.9% jank120=62.2%
    ghost-tab bend frames=481 build=0.7/1.2/4.5 raster=14.2/17.8/50.2 total=21.8/24.4/180.8 jank60=30.6% jank120=77.3%
    ghost-tab fold frames=257 build=37.4/15.9/1087.6 raster=83.2/107.1/1675.0 total=195.0/513.7/3062.7 jank60=66.9% jank120=86.8%
    ghost-tab fade frames=490 build=0.7/1.1/5.6 raster=12.4/18.2/23.8 total=17.2/23.4/72.8 jank60=29.0% jank120=67.3%
    memorize normal frames=491 build=0.3/0.4/4.2 raster=12.4/17.9/21.8 total=16.4/22.6/56.4 jank60=30.3% jank120=70.1%
    memorize curl frames=487 build=0.6/1.0/5.0 raster=13.3/18.3/38.0 total=19.2/22.2/151.9 jank60=33.3% jank120=75.2%
    memorize bend frames=455 build=0.9/1.5/6.6 raster=15.1/18.6/80.2 total=26.4/37.0/190.7 jank60=37.1% jank120=74.7%
    memorize fold frames=490 build=0.7/1.0/5.9 raster=12.2/17.8/24.6 total=15.9/21.2/53.0 jank60=29.2% jank120=68.2%
    memorize fade frames=485 build=0.7/1.2/7.1 raster=11.4/17.7/28.8 total=17.1/26.6/92.7 jank60=23.7% jank120=60.0%
### pt_index_before
    index-nomarks normal frames=64 lookup=11.1/14.4/14.4 ttff=230.9/270.1/270.1 settle=2080.7/3049.7/3049.7 build=13.5/38.5/157.7 raster=46.5/151.3/600.0 jank60=35
    index-nomarks curl frames=54 lookup=0.2/0.3/0.3 ttff=177.7/212.5/212.5 settle=1614.4/1726.7/1726.7 build=6.4/15.5/33.2 raster=33.9/154.0/185.5 jank60=18
    index-nomarks bend frames=61 lookup=0.4/0.5/0.5 ttff=164.2/168.5/168.5 settle=1642.5/1995.8/1995.8 build=8.0/21.7/42.7 raster=36.2/109.7/321.6 jank60=30
    index-nomarks fold frames=60 lookup=0.2/0.4/0.4 ttff=175.9/214.0/214.0 settle=1542.5/1691.6/1691.6 build=6.4/17.0/42.7 raster=30.9/132.8/172.4 jank60=26
    index-nomarks fade frames=58 lookup=0.5/0.7/0.7 ttff=165.5/177.8/177.8 settle=1551.5/1779.9/1779.9 build=9.6/19.6/95.0 raster=38.6/139.5/196.6 jank60=31
    index-marks-ribbon normal frames=51 lookup=0.2/0.2/0.2 ttff=159.9/252.4/252.4 settle=1252.0/1428.5/1428.5 build=5.5/13.2/22.0 raster=46.0/129.9/194.4 jank60=40
    index-marks-ribbon curl frames=61 lookup=1.3/3.2/3.2 ttff=204.1/306.2/306.2 settle=1416.6/1484.4/1484.4 build=6.0/13.4/43.6 raster=41.7/110.6/181.9 jank60=49
    index-marks-ribbon bend frames=44 lookup=0.2/0.2/0.2 ttff=234.7/394.5/394.5 settle=1630.1/1918.2/1918.2 build=8.5/18.9/61.2 raster=66.8/144.3/436.9 jank60=38
    index-marks-ribbon fold frames=55 lookup=0.3/0.4/0.4 ttff=190.5/242.8/242.8 settle=1480.7/1587.5/1587.5 build=6.1/13.7/43.9 raster=46.7/110.2/257.3 jank60=42
    index-marks-ribbon fade frames=48 lookup=0.1/0.1/0.1 ttff=147.6/200.3/200.3 settle=1083.7/1401.0/1401.0 build=5.2/13.2/29.1 raster=37.5/121.0/147.0 jank60=36
    index-marks-tab normal frames=50 lookup=0.2/0.4/0.4 ttff=141.2/214.2/214.2 settle=1643.2/2090.5/2090.5 build=6.9/20.1/39.2 raster=55.5/163.8/270.6 jank60=38
    index-marks-tab curl frames=55 lookup=0.5/1.3/1.3 ttff=435.8/1044.5/1044.5 settle=2730.0/4952.2/4952.2 build=16.5/30.5/261.5 raster=95.7/215.2/782.9 jank60=42
    index-marks-tab bend frames=56 lookup=0.2/0.5/0.5 ttff=211.4/406.2/406.2 settle=1677.6/2095.4/2095.4 build=6.7/19.4/33.3 raster=56.0/160.8/311.2 jank60=47
    index-marks-tab fold frames=58 lookup=0.4/0.5/0.5 ttff=184.0/260.3/260.3 settle=1298.5/1463.3/1463.3 build=6.3/18.5/48.5 raster=38.6/108.0/186.5 jank60=47
    index-marks-tab fade frames=67 lookup=0.8/1.6/1.6 ttff=184.0/235.1/235.1 settle=1858.6/2217.9/2217.9 build=11.2/26.1/210.1 raster=52.5/138.1/437.5 jank60=51
### pt_index_after
    index-nomarks normal frames=51 lookup=84.0/226.8/226.8 ttff=334.1/476.7/476.7 settle=7018.6/15427.2/15427.2 build=13.9/32.7/120.6 raster=332.1/182.4/12129.4 jank60=31
    index-nomarks curl frames=59 lookup=0.4/1.1/1.1 ttff=145.2/170.1/170.1 settle=2941.6/4910.0/4910.0 build=14.4/24.0/278.4 raster=76.6/169.5/1356.2 jank60=32
    index-nomarks bend frames=60 lookup=0.1/0.1/0.1 ttff=172.0/182.3/182.3 settle=30209.7/63867.7/63867.7 build=37.1/62.6/1307.5 raster=338.0/945.5/9058.7 jank60=37
