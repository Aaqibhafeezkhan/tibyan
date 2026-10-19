"""Recording player, mistake annotations API, waveform peaks."""
from __future__ import annotations

import array
import json
import secrets
import wave
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, Form, Query, Request
from fastapi.responses import JSONResponse, Response
from sqlalchemy.orm import Session
from starlette.responses import RedirectResponse

from .. import alignment
from .. import annotations as ann
from .. import verses
from ..config import settings
from ..deps import current_user, get_db
from ..i18n import STRINGS, get_lang
from ..models import AnnotationSet, Recording
from ..web import check_csrf, msg, render

router = APIRouter()

PEAK_BUCKETS = 800


def _media() -> Path:
    return Path(settings.media_dir).resolve()


def _err(code: str, status: int) -> JSONResponse:
    return JSONResponse({"error": code}, status_code=status)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


# ------------------------------------------------------------------ peaks

def compute_peaks(path: Path, buckets: int = PEAK_BUCKETS) -> list[float]:
    """Max |sample| per bucket of a 16-bit mono WAV, 0..1, 3 decimals."""
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2:
            raise ValueError("16-bit WAV expected")
        channels = w.getnchannels()
        data = array.array("h")
        data.frombytes(w.readframes(w.getnframes()))
    if channels > 1:
        data = data[::channels]
    n = len(data)
    if n == 0:
        return []
    buckets = max(1, min(buckets, n))
    size = n / buckets
    out = []
    for i in range(buckets):
        chunk = data[int(i * size) : max(int((i + 1) * size), int(i * size) + 1)]
        out.append(round(max(abs(min(chunk)), abs(max(chunk))) / 32768, 3))
    top = max(out) or 1
    return [round(v / top, 3) for v in out]


def cached_peaks(rec: Recording) -> list[float] | None:
    src = _media() / rec.audio_path if rec.audio_path else None
    if src is None or not src.is_file():
        return None
    cache = _media() / "peaks" / f"{rec.id}.json"
    if cache.is_file() and cache.stat().st_mtime >= src.stat().st_mtime:
        try:
            return json.loads(cache.read_text())
        except ValueError:
            pass
    peaks = compute_peaks(src)
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(peaks))
    return peaks


@router.get("/recordings/{recording_id}/peaks.json")
def recording_peaks(recording_id: int, request: Request, db: Session = Depends(get_db)):
    user = current_user(request, db)
    rec = db.get(Recording, recording_id)
    if user is None:
        return _err("login", 401)
    if rec is None or not ann.can_view(db, rec, user):
        return _err("not_found", 404)
    try:
        peaks = cached_peaks(rec)
    except (ValueError, wave.Error, EOFError):
        peaks = None
    if peaks is None:
        return _err("audio_unavailable", 404)
    return JSONResponse(
        {"duration_ms": rec.audio_duration_ms, "peaks": peaks},
        headers={"Cache-Control": "private, max-age=3600"},
    )


# ------------------------------------------------------------ player page

JS_KEYS = [k for k in STRINGS["ar"] if k.startswith("pl_")]


def player_context(db: Session, rec: Recording, user, role: str | None, lang: str) -> dict:
    words = ann.words_for(rec)
    timing = alignment.word_timings(rec, [w["text"] for w in words])
    latest = ann.latest_set(db, rec.id)
    auth = ann.authoritative_set(db, rec.id)
    # Editors start from the latest version; it is what they will replace.
    shown = latest if role else auth
    return {
        "id": rec.id,
        "duration_ms": rec.audio_duration_ms,
        "audio": f"/recordings/{rec.id}/audio",
        "peaks": f"/recordings/{rec.id}/peaks.json",
        "save": f"/recordings/{rec.id}/annotations",
        "download": f"/recordings/{rec.id}/annotations.json",
        "role": role,
        "base_version": latest.version if latest else 0,
        "shown_version": shown.version if shown else None,
        "shown_role": shown.author_role if shown else None,
        "authoritative_version": auth.version if auth else None,
        "words": words,
        "timing": timing,
        "mistakes": [
            ann.mistake_json(m) for m in ann.mistakes_of(db, shown)
        ],
        "lang": lang,
        "i18n": {k: STRINGS[lang][k] for k in JS_KEYS},
    }


@router.get("/recordings/{recording_id}")
def player_page(recording_id: int, request: Request, db: Session = Depends(get_db), new: int = 0):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    rec = db.get(Recording, recording_id)
    if rec is None or not ann.can_view(db, rec, user):
        return RedirectResponse("/dashboard", status_code=303)
    role = ann.role_for(db, rec, user)
    lang = get_lang(request)
    surah = next((s for s in verses.surahs() if s["number"] == rec.surah), None)
    return render(
        request,
        "player.html",
        rec=rec,
        surah_name=(surah or {}).get("name_ar" if lang == "ar" else "name_en", ""),
        player=player_context(db, rec, user, role, lang),
        is_new=bool(new),
        status_label=msg(request, f"status_{rec.status}"),
        flash=request.session.pop("flash", None),
    )


# ------------------------------------------------------------- annotations

@router.get("/recordings/{recording_id}/annotations.json")
def annotations_json(
    recording_id: int,
    request: Request,
    db: Session = Depends(get_db),
    version: int | None = Query(None, ge=1),
    download: int = 0,
):
    user = current_user(request, db)
    if user is None:
        return _err("login", 401)
    rec = db.get(Recording, recording_id)
    if rec is None or not ann.can_view(db, rec, user):
        return _err("not_found", 404)
    set_ = None
    if version is not None:
        set_ = ann.get_set(db, rec.id, version)
        if set_ is None:
            return _err("not_found", 404)
    doc = ann.document(db, rec, set_)
    headers = {"Cache-Control": "private, no-store"}
    if download:
        v = doc["version"]["number"] if doc["version"] else 0
        headers["Content-Disposition"] = (
            f'attachment; filename="tibyan-rec-{rec.id}-mistakes-v{v}.json"'
        )
    return Response(
        json.dumps(doc, ensure_ascii=False, indent=2),
        media_type="application/json; charset=utf-8",
        headers=headers,
    )


def _rate_limited(db: Session, user_id: int) -> bool:
    since = _now() - timedelta(seconds=60)
    recent = (
        db.query(AnnotationSet)
        .filter(AnnotationSet.author_id == user_id, AnnotationSet.created_at >= since)
        .count()
    )
    return recent >= settings.annotation_saves_per_minute


@router.post("/recordings/{recording_id}/annotations")
async def save_annotations(recording_id: int, request: Request, db: Session = Depends(get_db)):
    user = current_user(request, db)
    if user is None:
        return _err("login", 401)
    sent = request.headers.get("x-csrf-token", "")
    if not sent or not secrets.compare_digest(request.session.get("csrf", ""), sent):
        return _err("csrf", 403)
    rec = db.get(Recording, recording_id)
    if rec is None:
        return _err("not_found", 404)
    role = ann.role_for(db, rec, user)
    if role is None:
        return _err("forbidden", 403)
    body = await request.body()
    if len(body) > ann.MAX_BODY_BYTES:
        return _err("too_large", 413)
    try:
        payload = json.loads(body or b"{}")
    except ValueError:
        return _err("bad_json", 400)
    if not isinstance(payload, dict):
        return _err("bad_json", 400)
    if _rate_limited(db, user.id):
        return _err("rate_limited", 429)
    base = payload.get("base_version", 0)
    if isinstance(base, bool) or not isinstance(base, int):
        return _err("bad_version", 400)
    words = ann.words_for(rec)
    try:
        clean = ann.clean_mistakes(
            payload.get("mistakes"), len(words), rec.audio_duration_ms or 0, role
        )
        new = ann.save_version(db, rec, user, role, clean, base)
    except ann.AnnotationError as exc:
        if str(exc) == "conflict":
            latest = ann.latest_set(db, rec.id)
            return JSONResponse(
                {"error": "conflict", "latest_version": latest.version if latest else 0},
                status_code=409,
            )
        return _err(str(exc), 422)
    if role == "reciter" and new.version > 1:
        _notify_review_needed(db, rec)
    return JSONResponse(
        {
            "version": new.version,
            "author_role": new.author_role,
            "mistake_count": new.mistake_count,
            "annotation_status": rec.annotation_status,
            "has_mistakes": bool(rec.has_mistakes),
            "download": f"/recordings/{rec.id}/annotations.json?version={new.version}&download=1",
        },
        status_code=201,
    )


def _notify_review_needed(db: Session, rec: Recording) -> None:
    """A reciter edit after review sends the marks back to review."""
    if rec.status != "pending":
        from ..notifications import notify_admins

        notify_admins(db, "marks_review", {"id": rec.id}, "/validate")


# ---------------------------------------------------------- admin setting

@router.post("/admin/settings/mistakes-split")
def admin_mistakes_split(
    request: Request,
    db: Session = Depends(get_db),
    enabled: str = Form(""),
    csrf: str = Form(""),
):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    if not user.is_admin:
        return RedirectResponse("/dashboard", status_code=303)
    check_csrf(request, csrf)
    ann.set_setting(db, ann.SETTING_SPLIT, "1" if enabled == "1" else "0")
    request.session["flash"] = msg(request, "admin_split_saved")
    return RedirectResponse("/admin", status_code=303)
