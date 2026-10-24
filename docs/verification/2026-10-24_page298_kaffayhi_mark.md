# Page 298 (Madina 1441): the mark above «كَفَّيْهِ» (18:42)

Report: a small black, comma-like mark above «كَفَّيْهِ» while the page text
is drawn in the theme's ink.

## What the page artwork holds

`assets/pages/hafs-1441/298.svg.xz`: 34 paths in all.

- `#ayah_markers`: 11 ornaments and 11 verse numbers, all `fill="#231f20"`.
- `#content`: the whole page text as **one** compound path,
  `fill="#231f20"`, and 11 verse outlines (`ayahPolygon`,
  `fill-opacity="0"`, never visible).
- No strokes, no inline styles, no other colours, no other elements.

Above «كَفَّيْهِ» the artwork has only the shadda with its fatha over the fa
(and the kaf's own stroke), as in the KFGQPC print. They are part of the
same compound path as the letters, so they are not separate marks that could
be recoloured on their own. Nothing was removed or changed.

## The renderer

Every layer of the page (`_paintPage`, `_paintMarkers` in
`mushaf_page.dart`) is drawn inside a `saveLayer` with
`ColorFilter.mode(ink, BlendMode.srcIn)` whenever the mode is not plain
light, so any pixel the artwork draws takes the ink. Tajweed colours are
`srcATop` on that layer, and divine names are clipped `srcIn` layers. No path
can keep its own colour.

## Reproduction attempts (no black mark in any)

- `test/tools/render_page298_test.dart` (`RENDER_PAGE298=1`): page 298 in
  «البسيط» and «زخرفة», every mode (light, white, night, black), plain, with
  tajweed colours and with divine names (24 pictures, `build/page298/`).
- iOS simulator (iPhone 18 Pro, iOS 27, Impeller): night mode with the
  frame, and light mode in focus mode (line bands).
- The word box of 18:42 word 5 (x 189.9–242.9, y 332.6–357.6 in viewBox
  units) covers the shadda, so word tints (tasmee) also cover it.

## Scan of every page

`tools/scan_page_fills.py` over all 604 pages of `hafs-1441`:

- every fill is `#231f20`; 0 strokes, 0 inline styles, 0 other elements;
- 0 text paths without a fill (the only unfilled paths are the invisible
  verse outlines);
- the text is one compound path except on pages 1, 2 (2 paths, the
  opening pages), 17 (162) and 144 (146): all of them `#231f20` and
  recoloured the same way.

The 1405 edition and Shamarly are page images (PNG), recoloured whole; the
riwaya SVG packs are downloaded, not bundled, and were not scanned here
(the tool runs on any folder of `*.svg.xz`).

## Decision

No asset change and no renderer change: nothing in the artwork escapes the
ink, and the mark could not be reproduced. To go further we need the
owner's exact settings when it shows (style, mode, tajweed, divine names,
focus mode, a fasil tint, tasmee, or mid page turn) or the device.
