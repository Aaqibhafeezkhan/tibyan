"""Render an "آية اليوم" vertical reel (1080x1920) from the app's own data.

    python3 tools/video/ayah_reel.py 112 1-4 husary --out /path/reel.mp4

Nothing Quranic is typed here: the verse text and its words come from
content.db (assets/content_db parts, `ayah.display_text`), split exactly as
the app splits them (`_words` in lib/features/mushaf/mushaf_providers.dart,
`displayBody`/`displayNumber` in mushaf_repository.dart), and are drawn with
the app's Mushaf font (UthmanicHafs = assets/fonts/kfgqpc/uthmanic_hafs_v20.ttf).
Surah and reciter names come from content.db too. Word timings come from the
reciter's word-timing pack on the mirror (lib/features/audio/word_timing_*.dart),
checked against its SHA-256; audio is the same surah file the app plays
(`surahUrls` in recitation.dart: mirror first, then mp3quran).

Frames are drawn one by one in headless Chrome (tools/video/render_frames.mjs,
tools/video/ayah_reel.html), then muxed with the audio in one ffmpeg pass.
"""

import argparse
import gzip
import hashlib
import json
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RECITERS = {"minshawi": 1, "husary": 2}
MIRROR = "https://tibyan.ahmedhelal.dev/mirror/sources/recitations"
PACKS = "https://tibyan.ahmedhelal.dev/mirror/packs/timing/"
FPS = 30
INTRO, OUTRO, LEAD, TAIL = 2.0, 3.5, 0.25, 0.8  # seconds
MAX_LEN = 32.0


def content_db(cache: Path) -> Path:
    man = json.loads((ROOT / "assets/content_db/manifest.json").read_text())
    out = cache / "content.db"
    if out.exists() and hashlib.sha256(out.read_bytes()).hexdigest() == man["sha256"]:
        return out
    data = b"".join((ROOT / "assets/content_db" / p).read_bytes() for p in man["parts"])
    if hashlib.sha256(data).hexdigest() != man["sha256"]:
        sys.exit("content.db parts do not match manifest sha256")
    out.write_bytes(data)
    return out


def words_of(display_text: str):
    """(words, number glyph) exactly as the app splits the stored string."""
    split = max(display_text.rfind(" "), display_text.rfind(" "))
    body, number = display_text[:split], display_text[split + 1:]
    words = [w for w in re.split("[  ]", body) if w and w != "۞"]
    return words, number


def fetch(url: str, dest: Path, sha=None):
    if not dest.exists():
        req = urllib.request.Request(url, headers={"User-Agent": "tibyan-reel"})
        with urllib.request.urlopen(req, timeout=60) as r:
            dest.write_bytes(r.read())
    if sha and hashlib.sha256(dest.read_bytes()).hexdigest() != sha:
        dest.unlink()
        sys.exit(f"sha256 mismatch for {url}")
    return dest


def pack_spec(reciter: int):
    src = (ROOT / "lib/features/audio/word_timing_specs.dart").read_text()
    m = re.search(rf"\b{reciter}: WordTimingSpec\(\s*file: '([^']+)',\s*sha256: '([0-9a-f]+)'", src)
    if not m:
        sys.exit(f"no word timing pack for reciter {reciter}")
    return m.group(1), m.group(2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("surah", type=int)
    ap.add_argument("ayat", help="e.g. 1-4 or 255")
    ap.add_argument("reciter", choices=sorted(RECITERS))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--cache", type=Path, help="download/work dir (default: next to --out)")
    ap.add_argument("--keep-frames", action="store_true")
    ap.add_argument("--mushaf-frame", type=Path,
                    help="dir with frame_blank.png (+ banner.png when the app shows the surah banner above the first ayah) captured from the app; renders ayah_reel_mushaf.html")
    a = ap.parse_args()
    first, _, last = a.ayat.partition("-")
    first, last = int(first), int(last or first)
    rid = RECITERS[a.reciter]
    cache = a.cache or a.out.parent / "cache"
    cache.mkdir(parents=True, exist_ok=True)

    db = sqlite3.connect(content_db(cache))
    surah_name, = db.execute("select name_ar from surah where id=?", (a.surah,)).fetchone()
    reciter_name, folder = db.execute(
        "select name_ar, folder_url from reciter where id=?", (rid,)).fetchone()
    rows = db.execute("select number, display_text from ayah where surah=? and number between ? and ? "
                      "order by number", (a.surah, first, last)).fetchall()
    if len(rows) != last - first + 1:
        sys.exit("ayah range out of surah")

    file, sha = pack_spec(rid)
    pack = json.loads(gzip.decompress(fetch(PACKS + file, cache / file, sha).read_bytes()))
    verses = {v[0]: v for v in pack["surahs"][str(a.surah)]}
    surah_file = f"{a.surah:03d}.mp3"
    src_url = folder + surah_file
    mirror_url = MIRROR + urllib.parse.urlparse(src_url).path
    audio = cache / f"{rid}-{surah_file}"
    try:
        fetch(mirror_url, audio)
    except Exception:
        fetch(src_url, audio)

    t0 = verses[first][1] / 1000 - LEAD  # audio cut start (s in surah file)
    # a verse's end in the packs runs to the next verse's start; stop shortly after its last word instead
    t1 = min(verses[last][2] / 1000, verses[last][3][-1][2] / 1000 + TAIL)
    body = t1 - t0
    total = INTRO + body + OUTRO
    if total > MAX_LEN:
        print(f"warning: {total:.1f}s > {MAX_LEN}s; pick fewer ayat", file=sys.stderr)
    ayat = []
    for number, text in rows:
        words, glyph = words_of(text)
        # display_text carries no basmala (basmala_prefix counts chars of `text`)
        times = {w[0]: (w[1], w[2]) for w in verses[number][3]}
        if len(times) != len(words):
            sys.exit(f"{a.surah}:{number}: {len(words)} words but {len(times)} timings")
        ayat.append({"n": number, "glyph": glyph, "words": [
            {"t": w, "s": INTRO + times[i + 1][0] / 1000 - t0, "e": INTRO + times[i + 1][1] / 1000 - t0}
            for i, w in enumerate(words)]})

    spec = {
        "surah": surah_name, "surahId": a.surah, "range": f"{first}" if first == last else f"{first} إلى {last}",
        "reciter": reciter_name, "ayat": ayat, "intro": INTRO, "bodyEnd": INTRO + body,
        "total": total, "fps": FPS, "root": str(ROOT),
    }
    if a.mushaf_frame:
        spec.update(template="ayah_reel_mushaf.html",
                    frameImg=(a.mushaf_frame / "frame_blank.png").resolve().as_uri(),
                    bannerImg=(a.mushaf_frame / "banner.png").resolve().as_uri()
                    if (a.mushaf_frame / "banner.png").exists() else "")
        if (a.mushaf_frame / "inner.json").exists():  # text box of a page with its own layout (Al-Fatiha's page 1)
            spec["inner"] = json.loads((a.mushaf_frame / "inner.json").read_text())
    work = Path(tempfile.mkdtemp(prefix="reel-", dir=cache))
    (work / "spec.json").write_text(json.dumps(spec, ensure_ascii=False))
    frames = work / "frames"
    print(f"rendering {int(total * FPS)} frames ({total:.2f}s)…")
    subprocess.run(["node", str(HERE / "render_frames.mjs"), str(work / "spec.json"), str(frames)], check=True)

    a.out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", str(frames / "%05d.jpg"),
        "-ss", f"{t0:.3f}", "-t", f"{body:.3f}", "-i", str(audio),
        "-filter_complex",
        f"[1:a]afade=t=in:d=0.15,afade=t=out:st={body - 0.3:.3f}:d=0.3,"
        f"adelay={int(INTRO * 1000)}:all=1,apad[a]",
        "-map", "0:v", "-map", "[a]", "-t", f"{total:.3f}",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
        "-c:a", "aac", "-b:a", "160k", "-ar", "48000", "-movflags", "+faststart", str(a.out)], check=True)
    if not a.keep_frames:
        shutil.rmtree(work)
    print(a.out, f"{total:.2f}s", a.out.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
