"""POST /api/reports: bug reports, problems and suggestions from the app.

Public, JSON, no session/CSRF. Abuse controls: a body-size cap, a honeypot
field and a per-IP rate limit counted in the database (so it holds across
uvicorn workers). The client IP is request.client.host — uvicorn already
resolves X-Forwarded-For from the trusted local proxy only.
"""
from __future__ import annotations

import hashlib
import logging
import re
import smtplib
from datetime import timedelta
from typing import Literal, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, ValidationError, field_validator
from sqlalchemy.orm import Session

from ..config import settings
from ..deps import get_db
from ..email_brand import branded
from ..mail import send_mail, valid_email
from ..models import AppReport
from ..notifications import notify_admins
from ..push import utcnow

router = APIRouter()
logger = logging.getLogger(__name__)

MAX_BODY_BYTES = 16 * 1024
# (window, max reports per IP in that window)
RATE_LIMITS = ((timedelta(minutes=10), 5), (timedelta(days=1), 30))
_PHONE_RE = re.compile(r"^[0-9+\- ]+$")


def _blank_to_none(value):
    if isinstance(value, str):
        value = value.strip()
        return value or None
    return value


class ReportIn(BaseModel):
    type: Literal["bug", "problem", "suggestion", "other"]
    description: str = Field(min_length=5, max_length=4000)
    phone: Optional[str] = Field(default=None, max_length=32)
    email: Optional[str] = Field(default=None, max_length=254)
    app_version: Optional[str] = Field(default=None, max_length=64)
    platform: Optional[str] = Field(default=None, max_length=64)
    os_version: Optional[str] = Field(default=None, max_length=64)
    client_id: Optional[str] = Field(default=None, max_length=64)
    website: Optional[str] = Field(default=None, max_length=500)

    @field_validator("description", mode="before")
    @classmethod
    def _strip(cls, v):
        return v.strip() if isinstance(v, str) else v

    @field_validator(
        "phone", "email", "app_version", "platform", "os_version", "client_id", "website",
        mode="before",
    )
    @classmethod
    def _blank(cls, v):
        return _blank_to_none(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v):
        if v is not None and not _PHONE_RE.match(v):
            raise ValueError("phone may contain digits, +, - and spaces only")
        return v

    @field_validator("email")
    @classmethod
    def _email(cls, v):
        if v is not None:
            v = v.lower()
            if not valid_email(v):
                raise ValueError("invalid email")
        return v


def _ip_hash(request: Request) -> str:
    ip = request.client.host if request.client else "unknown"
    return hashlib.sha256(f"{settings.secret_key}|{ip}".encode()).hexdigest()


def _rate_limited(db: Session, ip_hash: str) -> bool:
    now = utcnow()
    for window, limit in RATE_LIMITS:
        n = (
            db.query(AppReport)
            .filter(AppReport.ip_hash == ip_hash, AppReport.created_at >= now - window)
            .count()
        )
        if n >= limit:
            return True
    return False


def _email_body(r: AppReport) -> str:
    lines = [
        f"Type: {r.type}",
        f"Report #{r.id} · {r.created_at:%Y-%m-%d %H:%M} UTC",
        f"App: {r.app_version or '-'} · {r.platform or '-'} {r.os_version or ''}".rstrip(),
        f"Phone: {r.phone or '-'}",
        f"Email: {r.email or '-'}",
        f"Client: {r.client_id or '-'}",
        "",
        r.description,
    ]
    return "\n".join(lines)


def deliver_report(report: dict) -> None:
    """Background: email the report; on no SMTP, log. Never raises."""
    to = settings.admin_report_email or settings.smtp_to
    try:
        text, html = branded("en", f"App report: {report['type']} #{report['id']}", report["body"])
        sent = send_mail(
            subject=f"[Tibyan report] {report['type']} #{report['id']}",
            body=text,
            html=html,
            to=to or None,
            reply_to=report.get("email"),
        )
        if not sent:
            logger.warning("SMTP is not configured; app report %s was saved only.", report["id"])
    except (OSError, smtplib.SMTPException, ValueError):
        logger.exception("Failed to email app report %s.", report["id"])


def _error(status: int, detail) -> JSONResponse:
    return JSONResponse({"detail": detail}, status_code=status)


@router.post("/api/reports")
async def create_report(
    request: Request, background: BackgroundTasks, db: Session = Depends(get_db)
):
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > MAX_BODY_BYTES:
        return _error(413, "Report too large.")
    raw = await request.body()
    if len(raw) > MAX_BODY_BYTES:
        return _error(413, "Report too large.")
    try:
        data = ReportIn.model_validate_json(raw or b"{}")
    except ValidationError as exc:
        errors = [
            {"field": ".".join(str(p) for p in e["loc"]), "msg": e["msg"]}
            for e in exc.errors(include_url=False, include_context=False, include_input=False)
        ]
        return _error(422, errors)

    if data.website:  # honeypot: look successful, store nothing
        return JSONResponse({"id": None}, status_code=202)

    ip_hash = _ip_hash(request)
    if _rate_limited(db, ip_hash):
        return JSONResponse(
            {"detail": "Too many reports. Try again later."},
            status_code=429,
            headers={"Retry-After": "600"},
        )

    report = AppReport(
        type=data.type,
        description=data.description,
        phone=data.phone,
        email=data.email,
        app_version=data.app_version,
        platform=data.platform,
        os_version=data.os_version,
        client_id=data.client_id,
        ip_hash=ip_hash,
        created_at=utcnow(),
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    # In-app notification + web push to admins (no-op where push is off).
    notify_admins(db, "app_report", {"type": report.type}, "/admin/requests?tab=reports")
    background.add_task(
        deliver_report,
        {"id": report.id, "type": report.type, "email": report.email, "body": _email_body(report)},
    )
    return JSONResponse({"id": report.id}, status_code=201)
