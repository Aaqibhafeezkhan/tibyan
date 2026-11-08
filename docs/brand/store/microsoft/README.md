# Microsoft Store assets

Listing artwork, tiles, screenshots, and the trailer for «تبيان - القرآن الكريم» (Store ID `9N944SZ21PTS`).

| Folder | Contents |
|---|---|
| `art/` | Poster (2:3), box art (1:1), super hero art (16:9, no title), branded key art, titled hero, featured square. `_preview.png` shows them all. |
| `tiles/` | App tile icons at 71, 150 and 300 px. |
| `screenshots/` | Desktop screenshots, 2880×1800, from the macOS App Store listing. |
| `video/tibyan-trailer-store.mp4` | 1920×1080 H.264 trailer. It has a silent AAC track, which Partner Center needs before it will process the upload. It has no music. |

## Regenerating

- `src/make_store_art.py` builds `art/`. Run it with Pillow.
- To regenerate the trailer:
  1. Copy `src/store_trailer_test.dart` into `integration_test/` in a worktree.
  2. Run `src/run_trailer.py`, which drives the macOS app and records each clip with ffmpeg.
  3. Run `src/compose.sh`, which places the clips on the brand background.

The MSIX package itself comes from `.github/workflows/msstore.yml` and is never committed.
