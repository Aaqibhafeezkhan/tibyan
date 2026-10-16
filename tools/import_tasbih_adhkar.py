"""Copies the misbaha's adhkar, verbatim with their references, into
assets/tasbih/adhkar.json, from two openly licensed sources at pinned
commits. No text is written by hand: each entry is the source's own text
and reference, chosen by its id.

    python3 -I tools/import_tasbih_adhkar.py

1. my-prayers/muslim-data-android (Apache-2.0): Hisn al-Muslim as SQLite.
   Item 69 (chapter 25, after the salam): tasbih, tahmid and takbir thirty
   three times each, and the tahlil that completes the hundred; Muslim 597.
   Item 53 (chapter 23, after the tashahhud): the salawat; al-Bukhari 3370
   and Muslim 406.
2. Seen-Arabic/Morning-And-Evening-Adhkar-DB (MIT): orders 34 and 33, a
   hundred times each.
"""

import json
import pathlib
import sqlite3
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent

MUSLIM_DATA = {
    "id": "muslimdata",
    "url": "https://github.com/my-prayers/muslim-data-android",
    "commit": "f7968b8765bfa23706751edadc3fed2fa17a9864",
    "license": "Apache-2.0",
    "path": "muslim-data/src/main/assets/database/muslim_db_v2.5.1.db",
}
# id -> the count to a round (none where the source gives no number).
MUSLIM_DATA_ITEMS = {69: 100, 53: None}
# Item 69 is said in stages: each of its three phrases 33 times, then the
# tahlil once. The stages are spans of the verbatim text, found from its
# own punctuation (the two commas and the bracketed count); no text is
# written here.
STAGE_COUNTS = {69: [33, 33, 33, 1]}


def stages(text: str, counts: list) -> list:
    first = text.index(",")
    second = text.index(",", first + 1)
    open_ = text.index("(")
    close = text.index(")", open_)

    def span(a: int, b: int) -> tuple:
        while text[a] == " ":
            a += 1
        while text[b - 1] == " ":
            b -= 1
        return a, b

    spans = [
        span(0, first),
        span(first + 1, second),
        span(second + 1, open_),
        span(close + 1, len(text)),
    ]
    assert len(spans) == len(counts)
    return [{"start": a, "end": b, "count": c} for (a, b), c in zip(spans, counts)]

SEEN = {
    "id": "seen",
    "url": "https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB",
    "commit": "29d7623fede52eca835a789025dfda866e8cfe44",
    "license": "MIT",
    "path": "ar.json",
}
SEEN_ORDERS = [34, 33]


def raw(src: dict) -> str:
    repo = src["url"].removeprefix("https://github.com/")
    return f"https://raw.githubusercontent.com/{repo}/{src['commit']}/{src['path']}"


def muslim_data() -> list:
    with tempfile.TemporaryDirectory() as tmp:
        db = pathlib.Path(tmp, "muslim.db")
        with urllib.request.urlopen(raw(MUSLIM_DATA)) as r:
            db.write_bytes(r.read())
        c = sqlite3.connect(db)
        out = []
        for item, count in MUSLIM_DATA_ITEMS.items():
            (text,) = c.execute(
                "SELECT item FROM azkar_item WHERE _id = ?", (item,)
            ).fetchone()
            (ref,) = c.execute(
                "SELECT t.reference FROM azkar_reference r "
                "JOIN azkar_reference_translation t ON t.reference_id = r._id "
                "WHERE r.item_id = ? AND t.language = 'ar'",
                (item,),
            ).fetchone()
            entry = {
                "id": f"muslimdata{item}",
                "text": text,
                "reference": ref,
                "count": count,
                "source": MUSLIM_DATA["id"],
            }
            if item in STAGE_COUNTS:
                entry["stages"] = stages(text, STAGE_COUNTS[item])
                assert sum(s["count"] for s in entry["stages"]) == count
            out.append(entry)
        c.close()
        return out


def seen() -> list:
    with urllib.request.urlopen(raw(SEEN)) as r:
        data = json.load(r)
    by_order = {e["order"]: e for e in data}
    return [
        {
            "id": f"seen{o}",
            "text": by_order[o]["content"],
            "reference": by_order[o]["source"],
            "count": by_order[o]["count"],
            "source": SEEN["id"],
        }
        for o in SEEN_ORDERS
    ]


def main() -> None:
    items = muslim_data() + seen()
    out = {
        "sources": [
            {k: s[k] for k in ("id", "url", "commit", "license")}
            for s in (MUSLIM_DATA, SEEN)
        ],
        "items": items,
    }
    path = ROOT / "assets/tasbih/adhkar.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")
    print(f"wrote {len(items)} adhkar to {path}")


if __name__ == "__main__":
    main()
