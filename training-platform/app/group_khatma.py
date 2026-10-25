"""«الختمة الجماعية» (group khatma): the state and its rules.

No accounts. A khatma is reached by its unguessable id (128 random bits).
The organizer and each claimer hold a secret on their own device; the
server keeps only its SHA-256. Stored: id, title, the names people type,
part states and timestamps. Nothing else (no IP, e-mail or phone).

Retention: deleted 30 days after completion, or 180 days after the last
activity (cleanup(), run lazily on requests and periodically).
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
import time
import unicodedata
from datetime import date, datetime, timedelta, timezone
from threading import Lock

from sqlalchemy import or_
from sqlalchemy.orm import Session

from .models import GroupKhatma, GroupKhatmaPart

UNITS = {"juz": 30, "hizb": 60}
NAME_MAX = 40
TITLE_MAX = 80
DONE_KEEP = timedelta(days=30)
IDLE_KEEP = timedelta(days=180)
ROOT_ORIGIN = "https://altibyan.app"


class KhatmaError(Exception):
    def __init__(self, status: int, code: str):
        super().__init__(code)
        self.status = status
        self.code = code


def now() -> datetime:
    """Naive UTC (the DATETIME columns hold UTC)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def new_secret() -> str:
    return secrets.token_urlsafe(32)


def hash_secret(secret: str) -> str:
    return hashlib.sha256(secret.encode("utf-8")).hexdigest()


def secret_ok(secret: str | None, stored: str | None) -> bool:
    if not secret or not stored or len(secret) > 128:
        return False
    return hmac.compare_digest(hash_secret(secret), stored)


def clean_text(value, limit: int, *, required: bool) -> str | None:
    """Trim, drop control characters, cap at [limit] characters."""
    if value is None:
        value = ""
    if not isinstance(value, str):
        raise KhatmaError(422, "invalid_text")
    text = "".join(
        ch for ch in value if unicodedata.category(ch) not in ("Cc", "Cf")
        or ch in ("‌", "‍")
    )
    text = " ".join(text.split())
    if not text:
        if required:
            raise KhatmaError(422, "name_required")
        return None
    if len(text) > limit:
        raise KhatmaError(422, "too_long")
    return text


def parse_target(value) -> date | None:
    if value in (None, ""):
        return None
    if not isinstance(value, str):
        raise KhatmaError(422, "invalid_date")
    try:
        target = date.fromisoformat(value)
    except ValueError as exc:
        raise KhatmaError(422, "invalid_date") from exc
    today = now().date()
    if target < today - timedelta(days=1) or target > today + timedelta(days=366 * 2):
        raise KhatmaError(422, "invalid_date")
    return target


def expired(k: GroupKhatma, at: datetime | None = None) -> bool:
    at = at or now()
    if k.completed_at is not None and at - k.completed_at > DONE_KEEP:
        return True
    return at - k.last_activity_at > IDLE_KEEP


def cleanup(db: Session, at: datetime | None = None) -> int:
    """Delete expired khatmas and their parts; returns how many."""
    at = at or now()
    ids = [
        row[0]
        for row in db.query(GroupKhatma.id).filter(
            or_(
                GroupKhatma.completed_at < at - DONE_KEEP,
                GroupKhatma.last_activity_at < at - IDLE_KEEP,
            )
        )
    ]
    if not ids:
        return 0
    db.query(GroupKhatmaPart).filter(GroupKhatmaPart.khatma_id.in_(ids)).delete(
        synchronize_session=False
    )
    db.query(GroupKhatma).filter(GroupKhatma.id.in_(ids)).delete(
        synchronize_session=False
    )
    db.commit()
    return len(ids)


_last_cleanup = 0.0
_cleanup_lock = Lock()


def maybe_cleanup(db: Session, every: float = 3600.0) -> None:
    """Lazy cleanup: at most once an hour per worker."""
    global _last_cleanup
    with _cleanup_lock:
        if time.monotonic() - _last_cleanup < every:
            return
        _last_cleanup = time.monotonic()
    cleanup(db)


def reset_cleanup_clock() -> None:
    global _last_cleanup
    _last_cleanup = 0.0


def create(db: Session, data: dict) -> tuple[GroupKhatma, str]:
    unit = data.get("unit") or "juz"
    if unit not in UNITS:
        raise KhatmaError(422, "invalid_unit")
    title = clean_text(data.get("title"), TITLE_MAX, required=False)
    organizer = clean_text(data.get("organizer"), NAME_MAX, required=False)
    target = parse_target(data.get("target_date"))
    secret = new_secret()
    at = now()
    k = GroupKhatma(
        id=secrets.token_urlsafe(16),
        title=title,
        organizer=organizer,
        unit=unit,
        parts=UNITS[unit],
        target_date=target,
        organizer_hash=hash_secret(secret),
        created_at=at,
        last_activity_at=at,
    )
    db.add(k)
    db.add_all(
        GroupKhatmaPart(khatma_id=k.id, number=n, state="open")
        for n in range(1, k.parts + 1)
    )
    db.commit()
    return k, secret


def load(db: Session, khatma_id: str) -> GroupKhatma:
    if not khatma_id or len(khatma_id) > 32:
        raise KhatmaError(404, "not_found")
    k = db.get(GroupKhatma, khatma_id)
    if k is None:
        raise KhatmaError(404, "not_found")
    if expired(k):
        cleanup(db)
        raise KhatmaError(404, "not_found")
    return k


def parts_of(db: Session, k: GroupKhatma) -> list[GroupKhatmaPart]:
    return (
        db.query(GroupKhatmaPart)
        .filter(GroupKhatmaPart.khatma_id == k.id)
        .order_by(GroupKhatmaPart.number)
        .all()
    )


def part_of(db: Session, k: GroupKhatma, number: int) -> GroupKhatmaPart:
    p = (
        db.query(GroupKhatmaPart)
        .filter(GroupKhatmaPart.khatma_id == k.id, GroupKhatmaPart.number == number)
        .one_or_none()
    )
    if p is None:
        raise KhatmaError(404, "no_such_part")
    return p


def _iso(value) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.replace(microsecond=0).isoformat() + "Z"
    return value.isoformat()


def _touch(db: Session, k: GroupKhatma) -> None:
    at = now()
    k.last_activity_at = at
    db.flush()
    done = (
        db.query(GroupKhatmaPart)
        .filter(GroupKhatmaPart.khatma_id == k.id, GroupKhatmaPart.state == "done")
        .count()
    )
    if done >= k.parts:
        k.completed_at = k.completed_at or at
    else:
        k.completed_at = None
    db.commit()


def claim(db: Session, k: GroupKhatma, number: int, name) -> str:
    name = clean_text(name, NAME_MAX, required=True)
    p = part_of(db, k, number)
    if p.state != "open":
        raise KhatmaError(409, "taken")
    secret = new_secret()
    # Conditional update: of two people claiming the same part at once,
    # only one wins.
    won = (
        db.query(GroupKhatmaPart)
        .filter(GroupKhatmaPart.id == p.id, GroupKhatmaPart.state == "open")
        .update(
            {
                "state": "taken",
                "name": name,
                "secret_hash": hash_secret(secret),
                "claimed_at": now(),
                "done_at": None,
            },
            synchronize_session=False,
        )
    )
    if won != 1:
        db.rollback()
        raise KhatmaError(409, "taken")
    _touch(db, k)
    return secret


def mark_done(db: Session, k: GroupKhatma, number: int, secret: str | None) -> None:
    p = part_of(db, k, number)
    if p.state == "open" or not secret_ok(secret, p.secret_hash):
        raise KhatmaError(403, "forbidden")
    p.state = "done"
    p.done_at = now()
    _touch(db, k)


def undo_done(db: Session, k: GroupKhatma, number: int, secret: str | None) -> None:
    p = part_of(db, k, number)
    if p.state != "done" or not secret_ok(secret, p.secret_hash):
        raise KhatmaError(403, "forbidden")
    p.state = "taken"
    p.done_at = None
    _touch(db, k)


def release(db: Session, k: GroupKhatma, number: int, secret: str | None) -> None:
    """The claimer, or the organizer, frees a part."""
    p = part_of(db, k, number)
    if not (
        secret_ok(secret, p.secret_hash) or secret_ok(secret, k.organizer_hash)
    ):
        raise KhatmaError(403, "forbidden")
    p.state = "open"
    p.name = None
    p.secret_hash = None
    p.claimed_at = None
    p.done_at = None
    _touch(db, k)


def require_organizer(k: GroupKhatma, secret: str | None) -> None:
    if not secret_ok(secret, k.organizer_hash):
        raise KhatmaError(403, "forbidden")


def rename(db: Session, k: GroupKhatma, secret: str | None, title) -> None:
    require_organizer(k, secret)
    k.title = clean_text(title, TITLE_MAX, required=False)
    _touch(db, k)


def delete(db: Session, k: GroupKhatma, secret: str | None) -> None:
    require_organizer(k, secret)
    db.query(GroupKhatmaPart).filter(GroupKhatmaPart.khatma_id == k.id).delete(
        synchronize_session=False
    )
    db.delete(k)
    db.commit()


def public(db: Session, k: GroupKhatma) -> dict:
    """What anyone with the link sees (never a hash)."""
    parts = parts_of(db, k)
    return {
        "id": k.id,
        "url": f"{ROOT_ORIGIN}/k/{k.id}",
        "title": k.title,
        "organizer": k.organizer,
        "unit": k.unit,
        "parts_count": k.parts,
        "target_date": _iso(k.target_date),
        "created_at": _iso(k.created_at),
        "updated_at": _iso(k.last_activity_at),
        "completed_at": _iso(k.completed_at),
        "taken": sum(1 for p in parts if p.state != "open"),
        "done": sum(1 for p in parts if p.state == "done"),
        "parts": [
            {
                "number": p.number,
                "state": p.state,
                "name": p.name,
                "claimed_at": _iso(p.claimed_at),
                "done_at": _iso(p.done_at),
            }
            for p in parts
        ],
    }
