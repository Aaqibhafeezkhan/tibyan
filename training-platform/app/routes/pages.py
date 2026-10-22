from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Form, Request
from sqlalchemy.orm import Session
from starlette.responses import FileResponse, PlainTextResponse, RedirectResponse, Response

from ..deps import current_user, get_db
from ..mail import valid_email
from ..models import DeletionRequest, Recording
from ..notifications import notify_admins
from ..stats import public_progress
from ..launch_mail import TESTFLIGHT_URL
from ..templating import STATIC_DIR, launch_at
from ..web import check_csrf, msg, render

router = APIRouter()

ROOT_HOSTS = {
    "altibya.app",
    "www.altibya.app",
    "altibyan.app",
    "www.altibyan.app",
}
ROOT_ORIGIN = "https://altibyan.app"
TRAIN_ORIGIN = "https://train.altibyan.app"
# Public, indexable pages of the training platform (the rest needs a login).
TRAIN_PUBLIC_PATHS = ("/", "/voice", "/register", "/login", "/contact")


def is_root_host(request: Request) -> bool:
    return (request.url.hostname or "").rstrip(".").lower() in ROOT_HOSTS


def launch_state(now: datetime | None = None) -> dict:
    """Countdown state at render time: before / last24 / live."""
    target = launch_at()
    left = (target - (now or datetime.now(timezone.utc))).total_seconds()
    phase = "live" if left <= 0 else ("last24" if left < 86400 else "before")
    return {"launch_iso": target.isoformat(), "launch_phase": phase}


@router.get("/")
def index(request: Request, db: Session = Depends(get_db)):
    if is_root_host(request):
        notify = request.session.pop("notify", None)
        if notify is None and request.query_params.get("n") == "busy":
            notify = "busy"  # nginx's 429 redirect lands here
        return render(
            request,
            "coming-soon.html",
            notify=notify,
            notify_email=request.session.pop("notify_email", ""),
            testflight_url=TESTFLIGHT_URL,
            **launch_state(),
        )

    user = current_user(request, db)
    return render(request, "index.html", user=user, progress=public_progress(db))


@router.get("/voice")
def voice(request: Request, db: Session = Depends(get_db)):
    """How volunteers' recordings are used and how to delete them."""
    if is_root_host(request):
        return RedirectResponse(f"{TRAIN_ORIGIN}/voice", status_code=301)
    return render(
        request,
        "voice.html",
        user=current_user(request, db),
        deletion=request.session.pop("deletion", None),
    )


PRIVACY_UPDATED = ("2026-10-19", "١٩ أكتوبر ٢٠٢٦", "19 October 2026")


def _privacy(request: Request, lang: str):
    if not is_root_host(request):
        suffix = "/en" if lang == "en" else ""
        return RedirectResponse(f"{ROOT_ORIGIN}/privacy{suffix}", status_code=301)
    iso, ar, en = PRIVACY_UPDATED
    return render(
        request,
        "privacy.html",
        lang=lang,
        dir="rtl" if lang == "ar" else "ltr",
        updated_iso=iso,
        updated_ar=ar,
        updated_en=en,
    )


@router.get("/privacy")
def privacy(request: Request):
    """The privacy policy (app, altibyan.app and the training platform):
    Arabic here, English at /privacy/en."""
    return _privacy(request, "ar")


@router.get("/privacy/en")
def privacy_en(request: Request):
    return _privacy(request, "en")


@router.post("/voice/delete-request")
def deletion_request(
    request: Request,
    db: Session = Depends(get_db),
    email: str = Form(""),
    scope: str = Form("account"),
    details: str = Form(""),
    website: str = Form(""),
    csrf: str = Form(""),
):
    """Ask the team to delete recordings or a whole account. A logged-in
    request is linked to the account; `website` is a honeypot."""
    check_csrf(request, csrf)
    user = current_user(request, db)
    email = email.strip().lower()[:255]
    if user is not None and not email:
        email = (user.email or "").lower()
    if website:
        request.session["deletion"] = "ok"
    elif not valid_email(email) or scope not in ("recordings", "account"):
        request.session["deletion"] = "invalid"
    else:
        row = DeletionRequest(
            user_id=user.id if user else None,
            email=email,
            scope=scope,
            details=details.strip()[:2000] or None,
        )
        db.add(row)
        db.commit()
        notify_admins(
            db, "deletion_request", {"scope": scope}, "/admin/requests?tab=deletion"
        )
        request.session["deletion"] = "ok"
    return RedirectResponse("/voice#delete-request", status_code=303)


@router.get("/robots.txt")
def robots(request: Request):
    if is_root_host(request):
        body = f"User-agent: *\nAllow: /\n\nSitemap: {ROOT_ORIGIN}/sitemap.xml\n"
    else:
        body = (
            "User-agent: *\n"
            "Disallow: /admin\n"
            "Disallow: /dashboard\n"
            "Disallow: /record\n"
            "Disallow: /recordings/\n"
            "Disallow: /validate\n"
            "Disallow: /logout\n"
            "Disallow: /lang/\n"
            f"\nSitemap: {TRAIN_ORIGIN}/sitemap.xml\n"
        )
    return PlainTextResponse(body)


@router.get("/sitemap.xml")
def sitemap(request: Request):
    if is_root_host(request):
        urls = [
            f"{ROOT_ORIGIN}/",
            f"{ROOT_ORIGIN}/beta",
            f"{ROOT_ORIGIN}/privacy",
            f"{ROOT_ORIGIN}/privacy/en",
        ]
    else:
        urls = [f"{TRAIN_ORIGIN}{path}" for path in TRAIN_PUBLIC_PATHS]
    entries = "".join(f"  <url><loc>{url}</loc></url>\n" for url in urls)
    body = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{entries}</urlset>\n"
    )
    return Response(body, media_type="application/xml")


@router.get("/favicon.ico")
def favicon():
    return FileResponse(
        f"{STATIC_DIR}/favicon.ico",
        media_type="image/x-icon",
        headers={"Cache-Control": "public, max-age=604800"},
    )


@router.get("/dashboard")
def dashboard(request: Request, db: Session = Depends(get_db)):
    user = current_user(request, db)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    flash = request.session.pop("flash", None)
    recordings = (
        db.query(Recording)
        .filter(Recording.user_id == user.id)
        .order_by(Recording.id.desc())
        .limit(20)
        .all()
    )
    status_label = lambda status: msg(request, f"status_{status}")
    from .. import annotations

    return render(
        request,
        "dashboard.html",
        mistake_counts=annotations.mistake_counts(db, [r.id for r in recordings]),
        user=user,
        flash=flash,
        recordings=recordings,
        status_label=status_label,
    )


@router.get("/lang/{code}")
def set_language(code: str, request: Request):
    if code not in ("ar", "en"):
        code = "ar"
    target = request.headers.get("referer") or "/"
    response = RedirectResponse(target, status_code=303)
    response.set_cookie(
        "lang", code, httponly=True, samesite="lax", max_age=31536000
    )
    return response
