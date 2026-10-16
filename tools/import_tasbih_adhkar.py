"""Copies the short tasbih adhkar, verbatim with their references, from
Seen-Arabic/Morning-And-Evening-Adhkar-DB (MIT) into assets/tasbih/adhkar.json.

No text is written by hand: the script downloads the pinned commit's ar.json
and keeps only the entries named in ORDERS, exactly as published.

    python3 -I tools/import_tasbih_adhkar.py
"""

import json
import pathlib
import urllib.request

REPO = "Seen-Arabic/Morning-And-Evening-Adhkar-DB"
COMMIT = "29d7623fede52eca835a789025dfda866e8cfe44"
URL = f"https://raw.githubusercontent.com/{REPO}/{COMMIT}/ar.json"
# The repeated short adhkar of the set (istighfar and tasbih, 100 times each).
ORDERS = [34, 33]

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main() -> None:
    with urllib.request.urlopen(URL) as r:
        data = json.load(r)
    by_order = {e["order"]: e for e in data}
    items = [
        {
            "id": f"seen{o}",
            "text": by_order[o]["content"],
            "reference": by_order[o]["source"],
            "count": by_order[o]["count"],
        }
        for o in ORDERS
    ]
    out = {
        "source": f"https://github.com/{REPO}",
        "commit": COMMIT,
        "license": "MIT",
        "items": items,
    }
    path = ROOT / "assets/tasbih/adhkar.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")
    print(f"wrote {len(items)} adhkar to {path}")


if __name__ == "__main__":
    main()
