from __future__ import annotations

import random
from pathlib import Path

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from starlette.responses import RedirectResponse

from .. import annotations as ann
from .. import verses
from ..i18n import get_lang
from ..config import settings
from ..deps import current_user, get_db
from ..models import ClipReport, Recording, RecordingVote
from ..web import check_csrf, msg, render

router = APIRouter()

ACCEPTS_TO_ADMIT = 2
REJECTS_TO_DROP = 2


def media_root() -> Path:
    return Path(settings.media_dir).resolve()


def _status_label(request: Request, status: str) -> str:
    return msg(request, f"status_{status}")


def _pick_for_review(db: Session, user_id: int) -> Recording | None:
    """A pending recording this user has not voted on, or — when none is
    left — an already accepted recording whose marks the reciter edited
    after review (annotation_status == pending_review) and this user has
    not reviewed since."""
    voted_ids = [
        row[0]
        for row in db.query(RecordingVote.recording_id)
        .filter(RecordingVote.user_id == user_id)
        .all()
    ]
    query = db.query(Recording).filter(
        Recording.status == "pending",
        Recording.user_id != user_id,
    )
    if voted_ids:
        query = query.filter(~Recording.id.in_(voted_ids))
    candidates = query.order_by(Recording.id.desc()).limit(50).all()
    if not candidates:
        candidates = [
            rec
            for rec in db.query(Recording)
            .filter(
                Recording.status == "accepted",
                Recording.annotation_status == "pending_review",
                Recording.user_id != user_id,
            )
            .order_by(Recording.id.desc())
            .limit(50)
            .all()
            if not _reviewed_latest(db, rec.id, user_id)
        ]
    if not candidates:
        return None
    return random.choice(candidates)


def _reviewed_latest(db: Session, recording_id: int, user_id: int) -> bool:
    latest = ann.latest_set(db, recording_id)
    return latest is not None and latest.author_id == user_id


@router.get("/validate")
def validate_form(request: Request, db: Session = Depends(get_db)):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    clip = _pick_for_review(db, user.id)
    if clip is None:
        return render(request, "validate.html", clip=None)
    flash = request.session.pop("flash", None)
    from .annotations import player_context

    return render(
        request,
        "validate.html",
        clip=clip,
        marks_only=clip.status != "pending",
        player=player_context(db, clip, user, "reviewer", get_lang(request)),
        text=verses.ayah_range_text(
            clip.surah, clip.ayah, clip.ayah_end or clip.ayah
        ) or "",
        surah_name=next(
            (s["name_ar"] for s in verses.surahs() if s["number"] == clip.surah),
            "",
        ),
        flash=flash,
    )


@router.get("/recordings/{recording_id}/audio")
def recording_audio(recording_id: int, request: Request, db: Session = Depends(get_db)):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    rec = db.get(Recording, recording_id)
    if rec is None:
        return RedirectResponse("/validate", status_code=303)
    path = media_root() / rec.audio_path
    if not path.is_file():
        return RedirectResponse("/validate", status_code=303)
    return FileResponse(path, media_type="audio/wav")


@router.post("/validate/{recording_id}")
def submit_vote(
    recording_id: int,
    request: Request,
    db: Session = Depends(get_db),
    verdict: str = Form(""),
    csrf: str = Form(""),
):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    check_csrf(request, csrf)

    if verdict not in ("accept", "reject"):
        return RedirectResponse("/validate", status_code=303)

    rec = db.get(Recording, recording_id)
    if (
        rec is None
        or rec.status != "pending"
        or rec.user_id == user.id
    ):
        return RedirectResponse("/validate", status_code=303)

    already = (
        db.query(RecordingVote)
        .filter(
            RecordingVote.recording_id == recording_id,
            RecordingVote.user_id == user.id,
        )
        .first()
    )
    if already is not None:
        return RedirectResponse("/validate", status_code=303)

    db.add(
        RecordingVote(
            recording_id=recording_id,
            user_id=user.id,
            verdict=verdict,
        )
    )
    db.flush()

    accepts = (
        db.query(RecordingVote)
        .filter(
            RecordingVote.recording_id == recording_id,
            RecordingVote.verdict == "accept",
        )
        .count()
    )
    rejects = (
        db.query(RecordingVote)
        .filter(
            RecordingVote.recording_id == recording_id,
            RecordingVote.verdict == "reject",
        )
        .count()
    )
    if accepts >= ACCEPTS_TO_ADMIT:
        rec.status = "accepted"
    elif rejects >= REJECTS_TO_DROP:
        rec.status = "rejected"
    db.commit()
    if rec.status in ("accepted", "rejected"):
        from .admin import notify_owner_of_decision

        notify_owner_of_decision(db, rec)

    request.session["flash"] = msg(request, "validate_thanks")
    return RedirectResponse("/validate", status_code=303)


@router.post("/validate/{recording_id}/report")
def submit_report(
    recording_id: int,
    request: Request,
    db: Session = Depends(get_db),
    reason: str = Form(""),
    csrf: str = Form(""),
):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    check_csrf(request, csrf)

    rec = db.get(Recording, recording_id)
    if rec is None or rec.user_id == user.id:
        return RedirectResponse("/validate", status_code=303)

    db.add(
        ClipReport(
            recording_id=recording_id,
            user_id=user.id,
            reason=reason.strip()[:500] or None,
        )
    )
    if rec.status == "pending":
        rec.status = "flagged"
    db.commit()

    request.session["flash"] = msg(request, "validate_report_sent")
    return RedirectResponse("/validate", status_code=303)
