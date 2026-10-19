from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from sqlalchemy.orm import Session

from . import annotations as ann
from . import verses
from .config import settings
from .models import Recording


def build_export(db: Session) -> dict:
    """Copy accepted recordings into media/export and write the NeMo manifest.

    The manifest is one JSON object per line:
        {"audio_filepath": "...", "duration": seconds, "text": "..."}
    The verse text is read verbatim from the verses loader (exported from
    content.db); it is never typed or edited here.

    Mistake annotations: each recording with a saved version gets
    `annotations/<id>.json` (schema tibyan.mistakes/1, authoritative
    version) and an `annotation_file` key in its manifest line. When the
    admin setting `mistakes_dataset_split` is on (default), recordings
    flagged has_mistakes go to `manifest_mistakes.jsonl` instead of the
    clean ASR `manifest.jsonl` (their verse-text label is not what was
    said). SHA256SUMS covers WAVs and annotation files.
    """
    accepted = (
        db.query(Recording)
        .filter(Recording.status == "accepted")
        .order_by(Recording.id)
        .all()
    )
    media = Path(settings.media_dir).resolve()
    root = media / "export"
    wavs = root / "wavs"
    wavs.mkdir(parents=True, exist_ok=True)
    notes_dir = root / "annotations"
    if notes_dir.is_dir():
        shutil.rmtree(notes_dir)
    notes_dir.mkdir(parents=True)
    split = ann.mistakes_split(db)

    lines: list[str] = []
    mistake_lines: list[str] = []
    checksums: list[str] = []
    for rec in accepted:
        src = media / rec.audio_path
        if not src.is_file():
            continue
        dst = wavs / f"{rec.id}.wav"
        shutil.copyfile(src, dst)
        sha = hashlib.sha256(dst.read_bytes()).hexdigest()
        checksums.append(f"{sha}  wavs/{rec.id}.wav")

        text = verses.ayah_range_text(
            rec.surah, rec.ayah, rec.ayah_end or rec.ayah
        ) or ""
        row = {
            "audio_filepath": f"wavs/{rec.id}.wav",
            "duration": round(rec.audio_duration_ms / 1000, 3),
            "text": text,
        }
        if ann.latest_set(db, rec.id) is not None:
            doc = json.dumps(ann.document(db, rec), ensure_ascii=False, indent=2)
            note_path = notes_dir / f"{rec.id}.json"
            note_path.write_text(doc + "\n", encoding="utf-8")
            checksums.append(
                f"{hashlib.sha256(note_path.read_bytes()).hexdigest()}  annotations/{rec.id}.json"
            )
            row["annotation_file"] = f"annotations/{rec.id}.json"
            row["has_mistakes"] = bool(rec.has_mistakes)
        line = json.dumps(row, ensure_ascii=False)
        if split and rec.has_mistakes:
            mistake_lines.append(line)
        else:
            lines.append(line)

    manifest = root / "manifest.jsonl"
    manifest.write_text(
        "\n".join(lines) + ("\n" if lines else ""), encoding="utf-8"
    )
    mistakes_manifest = root / "manifest_mistakes.jsonl"
    if mistake_lines:
        mistakes_manifest.write_text("\n".join(mistake_lines) + "\n", encoding="utf-8")
    else:
        mistakes_manifest.unlink(missing_ok=True)
    (root / "SHA256SUMS").write_text(
        "\n".join(checksums) + ("\n" if checksums else ""), encoding="utf-8"
    )
    return {
        "count": len(lines),
        "mistakes_count": len(mistake_lines),
        "manifest": str(manifest),
        "dir": str(root),
    }
