"""Mistake annotations on a recording (schema `tibyan.mistakes/1`).

State machine
=============

Two independent axes live on `recordings`:

* `status` — the AUDIO decision, unchanged from phase 3/4:
  `pending -> accepted | rejected` by two votes or an admin, `pending ->
  flagged` on a report. Annotations never move this axis: a recording with
  intentional mistakes is accepted like any other.
* `annotation_status` — the MARKS:
    - `NULL`/`none`      no version saved yet.
    - `pending_review`   the latest version is the reciter's. Set on every
                         reciter save, including an edit after a reviewer
                         already reviewed (owner decision 4). The recording
                         then returns to the /validate queue for marks review
                         even when its audio is already `accepted`; voting is
                         only offered while the audio is `pending`.
    - `reviewed`         the latest version is a reviewer's or an admin's.

Every save is a new `annotation_sets` row with `version = latest + 1`;
nothing is overwritten (history). The AUTHORITATIVE version is the latest
reviewer/admin version; when none exists, the latest reciter version.

`has_mistakes` is true when the authoritative version lists at least one
mistake (marks a reviewer called `not_mistake` do not count) — or, while a
reciter edit is pending review, when that pending version does. So a
recording never slips into the clean ASR manifest while someone claims it
contains mistakes.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from . import verses
from .models import (
    AnnotationMistake,
    AnnotationSet,
    PlatformSetting,
    Recording,
    RecordingVote,
    User,
)

SCHEMA = "tibyan.mistakes/1"
TYPES = ("substitution", "deletion", "insertion", "haraka", "repetition", "tajweed")
TAJWEED_SUBTYPES = ("madd", "ghunna", "idgham", "ikhfa", "qalqala", "other")
REVIEWS = ("confirmed", "changed", "not_mistake", "added")
ROLES = ("reciter", "reviewer", "admin")
MAX_NOTE = 500
MAX_SAID = 200
MAX_MISTAKES = 300
MAX_BODY_BYTES = 128 * 1024

SETTING_SPLIT = "mistakes_dataset_split"


class AnnotationError(ValueError):
    pass


# ---------------------------------------------------------------- settings

def get_setting(db: Session, key: str, default: str) -> str:
    row = db.get(PlatformSetting, key)
    return row.value if row is not None else default


def set_setting(db: Session, key: str, value: str) -> None:
    row = db.get(PlatformSetting, key)
    if row is None:
        db.add(PlatformSetting(key=key, value=value))
    else:
        row.value = value
    db.commit()


def mistakes_split(db: Session) -> bool:
    """Admin choice: recordings flagged «فيه أخطاء» go to a separate
    mistake-detection manifest and stay out of the clean ASR manifest.
    Default on: a verse-text label on a recording with mistakes is wrong."""
    return get_setting(db, SETTING_SPLIT, "1") == "1"


# ------------------------------------------------------------------- words

def words_for(rec: Recording) -> list[dict]:
    """The verse words, verbatim from verses.py, split on spaces."""
    out: list[dict] = []
    end = rec.ayah_end or rec.ayah
    for number in range(rec.ayah, end + 1):
        text = verses.ayah_text(rec.surah, number) or ""
        for word in text.split():
            out.append({"index": len(out), "ayah": number, "text": word})
    return out


# ------------------------------------------------------------ permissions

def can_review(db: Session, rec: Recording, user: User | None) -> bool:
    if user is None or rec.user_id == user.id:
        return False
    return rec.status == "pending" or rec.annotation_status == "pending_review"


def role_for(db: Session, rec: Recording, user: User | None) -> str | None:
    """Role a user saves with, or None when they may not save."""
    if user is None:
        return None
    if rec.user_id == user.id:
        return "reciter"
    if user.is_admin:
        return "admin"
    if can_review(db, rec, user):
        return "reviewer"
    return None


def can_view(db: Session, rec: Recording, user: User | None) -> bool:
    if user is None:
        return False
    if rec.user_id == user.id or user.is_admin or can_review(db, rec, user):
        return True
    took_part = (
        db.query(RecordingVote.id)
        .filter(RecordingVote.recording_id == rec.id, RecordingVote.user_id == user.id)
        .first()
        or db.query(AnnotationSet.id)
        .filter(AnnotationSet.recording_id == rec.id, AnnotationSet.author_id == user.id)
        .first()
    )
    return took_part is not None


# ---------------------------------------------------------------- queries

def latest_set(db: Session, recording_id: int) -> AnnotationSet | None:
    return (
        db.query(AnnotationSet)
        .filter(AnnotationSet.recording_id == recording_id)
        .order_by(AnnotationSet.version.desc())
        .first()
    )


def authoritative_set(db: Session, recording_id: int) -> AnnotationSet | None:
    reviewed = (
        db.query(AnnotationSet)
        .filter(
            AnnotationSet.recording_id == recording_id,
            AnnotationSet.author_role.in_(("reviewer", "admin")),
        )
        .order_by(AnnotationSet.version.desc())
        .first()
    )
    return reviewed or latest_set(db, recording_id)


def get_set(db: Session, recording_id: int, version: int) -> AnnotationSet | None:
    return (
        db.query(AnnotationSet)
        .filter(AnnotationSet.recording_id == recording_id, AnnotationSet.version == version)
        .first()
    )


def mistakes_of(db: Session, set_: AnnotationSet | None) -> list[AnnotationMistake]:
    if set_ is None:
        return []
    return (
        db.query(AnnotationMistake)
        .filter(AnnotationMistake.set_id == set_.id)
        .order_by(AnnotationMistake.start_ms, AnnotationMistake.id)
        .all()
    )


def history(db: Session, recording_id: int) -> list[AnnotationSet]:
    return (
        db.query(AnnotationSet)
        .filter(AnnotationSet.recording_id == recording_id)
        .order_by(AnnotationSet.version)
        .all()
    )


def mistake_counts(db: Session, recording_ids: list[int]) -> dict[int, int]:
    """Authoritative mistake count per recording (for list badges)."""
    out: dict[int, int] = {}
    for rid in recording_ids:
        s = authoritative_set(db, rid)
        if s is not None:
            out[rid] = s.mistake_count
    return out


# ------------------------------------------------------------- validation

def _int(value, code: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise AnnotationError(code)
    return value


def _text(value, limit: int, code: str) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise AnnotationError(code)
    value = value.strip()
    if len(value) > limit:
        raise AnnotationError(code)
    return value or None


def clean_mistakes(raw, word_count: int, duration_ms: int, role: str) -> list[dict]:
    if not isinstance(raw, list):
        raise AnnotationError("bad_mistakes")
    if len(raw) > MAX_MISTAKES:
        raise AnnotationError("too_many")
    out: list[dict] = []
    for item in raw:
        if not isinstance(item, dict):
            raise AnnotationError("bad_mistakes")
        kind = item.get("type")
        if kind not in TYPES:
            raise AnnotationError("bad_type")
        index = _int(item.get("word_index"), "bad_word")
        top = word_count if kind == "insertion" else word_count - 1
        if index < 0 or index > top:
            raise AnnotationError("bad_word")
        start = _int(item.get("start_ms"), "bad_time")
        end = _int(item.get("end_ms"), "bad_time")
        limit = max(duration_ms, 0) + 500  # rounding slack
        if start < 0 or end <= start or end > limit:
            raise AnnotationError("bad_time")
        subtype = item.get("subtype")
        if kind == "tajweed":
            if subtype not in TAJWEED_SUBTYPES:
                raise AnnotationError("bad_subtype")
        else:
            subtype = None
        said = _text(item.get("said"), MAX_SAID, "bad_said")
        if kind != "substitution":
            said = None
        note = _text(item.get("note"), MAX_NOTE, "bad_note")

        if role == "reciter":
            marked_by, review = "reciter", None
        else:
            marked_by = item.get("marked_by") or role
            if marked_by not in ROLES:
                raise AnnotationError("bad_mistakes")
            review = item.get("review")
            if review is None:
                review = "added" if marked_by != "reciter" else "confirmed"
            if review not in REVIEWS:
                raise AnnotationError("bad_review")
        out.append(
            {
                "word_index": index,
                "type": kind,
                "subtype": subtype,
                "start_ms": start,
                "end_ms": min(end, duration_ms) if duration_ms > start else end,
                "said": said,
                "note": note,
                "review": review,
                "marked_by": marked_by,
            }
        )
    return out


# ------------------------------------------------------------------ save

def _counts(mistakes) -> int:
    return sum(1 for m in mistakes if (m["review"] if isinstance(m, dict) else m.review) != "not_mistake")


def refresh_flags(db: Session, rec: Recording) -> None:
    auth = authoritative_set(db, rec.id)
    latest = latest_set(db, rec.id)
    if latest is None:
        rec.annotation_status = None
        rec.has_mistakes = None
        return
    rec.annotation_status = "pending_review" if latest.author_role == "reciter" else "reviewed"
    flagged = bool(auth and auth.mistake_count > 0)
    if rec.annotation_status == "pending_review" and latest.mistake_count > 0:
        flagged = True
    rec.has_mistakes = flagged


def save_version(
    db: Session,
    rec: Recording,
    user: User,
    role: str,
    mistakes: list[dict],
    base_version: int,
) -> AnnotationSet:
    """Insert a new version. Raises AnnotationError('conflict') when someone
    saved since the client loaded `base_version`."""
    latest = latest_set(db, rec.id)
    current = latest.version if latest else 0
    if base_version != current:
        raise AnnotationError("conflict")
    new = AnnotationSet(
        recording_id=rec.id,
        version=current + 1,
        author_id=user.id,
        author_role=role,
        mistake_count=_counts(mistakes),
        created_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(new)
    db.flush()
    for m in mistakes:
        db.add(AnnotationMistake(set_id=new.id, **m))
    db.flush()
    refresh_flags(db, rec)
    db.commit()
    db.refresh(new)
    return new


def delete_for_recording(db: Session, recording_id: int) -> None:
    ids = [s.id for s in db.query(AnnotationSet.id).filter(AnnotationSet.recording_id == recording_id)]
    if ids:
        db.query(AnnotationMistake).filter(AnnotationMistake.set_id.in_(ids)).delete(
            synchronize_session=False
        )
        db.query(AnnotationSet).filter(AnnotationSet.recording_id == recording_id).delete(
            synchronize_session=False
        )


# ---------------------------------------------------------------- export

def _iso(dt: datetime | None) -> str | None:
    return dt.replace(microsecond=0).isoformat() + "Z" if dt else None


def mistake_json(m: AnnotationMistake) -> dict:
    return {
        "word_index": m.word_index,
        "position": "before_word" if m.type == "insertion" else "word",
        "start_ms": m.start_ms,
        "end_ms": m.end_ms,
        "type": m.type,
        "subtype": m.subtype,
        "said": m.said,
        "note": m.note,
        "review": m.review,
        "marked_by": m.marked_by,
    }


def document(db: Session, rec: Recording, set_: AnnotationSet | None = None) -> dict:
    """The `tibyan.mistakes/1` document for one version (default: the
    authoritative one). Word text comes verbatim from verses.py."""
    from .alignment import word_timings

    auth = authoritative_set(db, rec.id)
    set_ = set_ or auth
    words = words_for(rec)
    timing = word_timings(rec, [w["text"] for w in words])
    for w, t in zip(words, timing["words"]):
        w["start_ms"], w["end_ms"] = t["start_ms"], t["end_ms"]
    marks = [mistake_json(m) for m in mistakes_of(db, set_)]
    return {
        "schema": SCHEMA,
        "recording_id": rec.id,
        "surah": rec.surah,
        "ayah_start": rec.ayah,
        "ayah_end": rec.ayah_end or rec.ayah,
        "audio_duration_ms": rec.audio_duration_ms,
        "audio_status": rec.status,
        "annotation_status": rec.annotation_status or "none",
        "has_mistakes": bool(rec.has_mistakes),
        "version": (
            {
                "number": set_.version,
                "author_role": set_.author_role,
                "created_at": _iso(set_.created_at),
                "authoritative": bool(auth and set_.id == auth.id),
            }
            if set_
            else None
        ),
        "text_source": "verses.json (verbatim export of the app's content.db)",
        "word_timing": {"source": timing["source"], "status": timing["status"]},
        "words": words,
        "mistakes": [m for m in marks if m["review"] != "not_mistake"],
        "rejected": [m for m in marks if m["review"] == "not_mistake"],
        "history": [
            {
                "version": h.version,
                "author_role": h.author_role,
                "created_at": _iso(h.created_at),
                "mistake_count": h.mistake_count,
            }
            for h in history(db, rec.id)
        ],
    }
