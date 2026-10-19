from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, Form, Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.responses import RedirectResponse

from .. import ratelimit
from ..deps import get_db
from ..i18n import get_lang
from ..launch_mail import send_notify_confirmation, send_signup_alert
from ..mail import valid_email
from ..models import NotifySignup
from ..notifications import notify_admins
from ..web import check_csrf

router = APIRouter()


@router.post("/notify")
def notify_submit(
    request: Request,
    background: BackgroundTasks,
    db: Session = Depends(get_db),
    email: str = Form(""),
    beta: bool = Form(False),
    website: str = Form(""),
    csrf: str = Form(""),
):
    """Store an address that wants launch news.

    `website` is a honeypot: bots get the same thank-you, nothing stored.
    A repeat address also gets the thank-you (no address enumeration) and
    no second email. `beta` is kept for old cached pages; the beta request
    itself now lives on /beta.
    """
    check_csrf(request, csrf)
    email = email.strip().lower()[:255]

    if website:
        request.session["notify"] = "ok"
    elif ratelimit.hit("notify", request):
        request.session["notify"] = "busy"
    elif not valid_email(email):
        request.session["notify"] = "invalid"
        request.session["notify_email"] = email[:255]
    else:
        lang = get_lang(request)
        existing = db.query(NotifySignup).filter(NotifySignup.email == email).first()
        new_beta = False
        if existing is None:
            db.add(NotifySignup(email=email, lang=lang, wants_beta=beta))
            try:
                db.commit()
                new_beta = beta
                background.add_task(send_notify_confirmation, email, lang)
                background.add_task(
                    send_signup_alert, "beta" if beta else "notify", email, lang
                )
            except IntegrityError:
                db.rollback()
        elif beta and not existing.wants_beta:
            existing.wants_beta = True
            db.commit()
            new_beta = True
        if new_beta:
            notify_admins(db, "beta_request", {}, "/admin/requests?tab=beta")
        request.session["notify"] = "ok"

    return RedirectResponse("/#notify", status_code=303)
