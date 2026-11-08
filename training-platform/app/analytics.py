"""Privacy-respecting counters for altibyan.app: downloads per platform per
day, page views per path per day, and unique visitors per day.

No cookies, no third-party trackers, no raw IPs. A visitor is the SHA-256 of
a random per-day salt + IP + user agent; the salt row is deleted when its day
ends. Writes run on a single background thread so a page or a download
redirect never waits for the database."""
from __future__ import annotations

import hashlib
import logging
import re
import secrets
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone

from sqlalchemy import func, update
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from . import db as app_db
from .models import DailyDownload, DailyPageView, DailyVisitor, VisitSalt

logger = logging.getLogger(__name__)

BOT_RE = re.compile(
    r"bot|crawl|spider|slurp|scrap|curl|wget|python|httpx|aiohttp|go-http|java/|"
    r"okhttp|libwww|headless|phantom|lighthouse|pingdom|uptime|monitor|"
    r"facebookexternalhit|preview|validator|scan|feed|fetch",
    re.I,
)
CACHE_SECONDS = 300

_executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="analytics")
_cache: dict = {"at": 0.0, "value": None}
_now = time.monotonic  # patched in tests
session_factory = None  # tests point this at their own sessionmaker


def _session():
    return (session_factory or app_db.SessionLocal)()


def today() -> date:
    return datetime.now(timezone.utc).date()


def is_bot(user_agent: str | None) -> bool:
    return not user_agent or bool(BOT_RE.search(user_agent))


def _bump(db, model, key_col: str, key: str, day: date) -> None:
    """count += 1 for (day, key), inserting the row the first time."""
    col = getattr(model, key_col)
    hit = db.execute(
        update(model).where(model.day == day, col == key).values(count=model.count + 1)
    ).rowcount
    if hit:
        db.commit()
        return
    db.add(model(day=day, count=1, **{key_col: key}))
    try:
        db.commit()
    except IntegrityError:  # another worker inserted it first
        db.rollback()
        db.execute(update(model).where(model.day == day, col == key).values(count=model.count + 1))
        db.commit()


def _salt(db, day: date) -> str:
    row = db.get(VisitSalt, day)
    if row is not None:
        return row.salt
    db.query(VisitSalt).filter(VisitSalt.day < day).delete()
    db.add(VisitSalt(day=day, salt=secrets.token_hex(32)))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
    return db.get(VisitSalt, day).salt


def _write_download(platform: str, day: date) -> None:
    db = _session()
    try:
        _bump(db, DailyDownload, "platform", platform, day)
    except SQLAlchemyError:
        logger.exception("Download counter failed.")
    finally:
        db.close()


def _write_visit(path: str, ip: str, user_agent: str, day: date) -> None:
    db = _session()
    try:
        _bump(db, DailyPageView, "path", path, day)
        salt = _salt(db, day)
        digest = hashlib.sha256(f"{salt}|{ip}|{user_agent}".encode()).hexdigest()
        if not db.query(DailyVisitor.id).filter_by(day=day, visitor_hash=digest).first():
            db.add(DailyVisitor(day=day, visitor_hash=digest))
            try:
                db.commit()
            except IntegrityError:
                db.rollback()
    except SQLAlchemyError:
        logger.exception("Visit counter failed.")
    finally:
        db.close()


def _submit(fn, *args) -> None:
    try:
        _executor.submit(fn, *args)
    except RuntimeError:  # interpreter shutting down
        pass


def record_download(platform: str, user_agent: str | None, method: str = "GET") -> None:
    if method != "GET" or is_bot(user_agent):
        return
    _submit(_write_download, platform, today())


def record_visit(path: str, ip: str, user_agent: str | None, method: str = "GET") -> None:
    if method != "GET" or is_bot(user_agent):
        return
    _submit(_write_visit, path[:191], ip, user_agent[:512], today())


def wait() -> None:
    """Block until queued writes are done (tests)."""
    _executor.submit(lambda: None).result()


def public_totals(db) -> dict | None:
    """{visits, downloads}: sum of daily unique visitors and all downloads.
    Cached per worker for 5 minutes; None hides the line if the DB fails."""
    now = _now()
    if _cache["value"] is not None and now - _cache["at"] < CACHE_SECONDS:
        return _cache["value"]
    if db is None:
        return None
    try:
        visits = db.query(func.count(DailyVisitor.id)).scalar() or 0
        downloads = db.query(func.coalesce(func.sum(DailyDownload.count), 0)).scalar() or 0
    except SQLAlchemyError:
        logger.exception("Public totals query failed.")
        return None
    value = {"visits": int(visits), "downloads": int(downloads)}
    _cache.update(at=now, value=value)
    return value


def reset_cache() -> None:
    _cache.update(at=0.0, value=None)


def daily_table(db, days: int = 30) -> list[dict]:
    """Newest first: [{day, visitors, views, downloads: {platform: n}, total}]."""
    rows: dict = {}

    def row(d):
        return rows.setdefault(d, {"day": d, "visitors": 0, "views": 0, "downloads": {}, "total": 0})

    for d, n in db.query(DailyVisitor.day, func.count(DailyVisitor.id)).group_by(DailyVisitor.day):
        row(d)["visitors"] = n
    for d, n in db.query(DailyPageView.day, func.sum(DailyPageView.count)).group_by(DailyPageView.day):
        row(d)["views"] = int(n or 0)
    for d, p, n in db.query(DailyDownload.day, DailyDownload.platform, DailyDownload.count):
        r = row(d)
        r["downloads"][p] = n
        r["total"] += n
    return [rows[d] for d in sorted(rows, reverse=True)[:days]]


def platform_totals(db) -> dict:
    return {
        p: int(n or 0)
        for p, n in db.query(DailyDownload.platform, func.sum(DailyDownload.count))
        .group_by(DailyDownload.platform)
        .order_by(DailyDownload.platform)
    }


def top_paths(db, limit: int = 20) -> list[tuple[str, int]]:
    return [
        (p, int(n or 0))
        for p, n in db.query(DailyPageView.path, func.sum(DailyPageView.count))
        .group_by(DailyPageView.path)
        .order_by(func.sum(DailyPageView.count).desc())
        .limit(limit)
    ]


AR_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def arabic_digits(value) -> str:
    """12345 -> ١٢٬٣٤٥ (Arabic thousands separator)."""
    return f"{int(value):,}".replace(",", "٬").translate(AR_DIGITS)


SKIP_PREFIXES = ("/static", "/download", "/admin", "/api", "/lang", "/notify", "/beta/join")
ROOT_HOSTS = ("altibyan.app", "www.altibyan.app", "altibya.app", "www.altibya.app")


def client_ip(request) -> str:
    # Cloudflare -> nginx -> uvicorn (proxy headers already resolve X-Forwarded-For).
    return request.headers.get("cf-connecting-ip") or (
        request.client.host if request.client else ""
    )


def count_page(request, response) -> None:
    """Count a public promo-site page view (root host, HTML, 200 only)."""
    host = (request.url.hostname or "").rstrip(".").lower()
    path = request.url.path
    if (
        host not in ROOT_HOSTS
        or response.status_code != 200
        or path.startswith(SKIP_PREFIXES)
        or not response.headers.get("content-type", "").startswith("text/html")
    ):
        return
    record_visit(path, client_ip(request), request.headers.get("user-agent"), request.method)
