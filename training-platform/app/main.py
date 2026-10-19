from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.exception_handlers import http_exception_handler
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.sessions import SessionMiddleware

from . import models  # noqa: F401  (register the tables)
from .config import settings
from .db import engine, run_migrations
from .routes import (
    admin,
    admin_requests,
    admin_training,
    annotations,
    auth,
    beta,
    contact,
    notifications,
    notify,
    pages,
    record,
    reports,
    runner,
    validate,
)
from .i18n import get_lang, t as translate
from .templating import STATIC_DIR, templates

run_migrations(engine)

app = FastAPI(title="Tibyan Recitation Training")

app.add_middleware(
    SessionMiddleware,
    secret_key=settings.secret_key,
    same_site="lax",
    https_only=settings.cookie_secure,
    max_age=7 * 24 * 3600,
)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
app.include_router(pages.router)
app.include_router(auth.router)
app.include_router(record.router)
app.include_router(validate.router)
app.include_router(admin.router)
app.include_router(contact.router)
app.include_router(notify.router)
app.include_router(beta.router)
app.include_router(admin_requests.router)
app.include_router(admin_training.router)
app.include_router(notifications.router)
app.include_router(runner.router)
app.include_router(reports.router)
app.include_router(annotations.router)


# ---------- branded error pages (HTML clients only; APIs keep JSON) ----------
ERROR_PAGES = (404, 429, 500)


def _wants_html(request: Request) -> bool:
    return (
        not request.url.path.startswith("/api/")
        and "text/html" in request.headers.get("accept", "")
    )


def error_page(request: Request, code: int):
    lang = get_lang(request)
    return templates.TemplateResponse(
        request,
        "error.html",
        {
            "code": code,
            "lang": lang,
            "dir": "rtl" if lang == "ar" else "ltr",
            "t": lambda key: translate(lang, key),
        },
        status_code=code,
        headers={"Cache-Control": "no-store"},
    )


@app.exception_handler(StarletteHTTPException)
async def html_http_errors(request: Request, exc: StarletteHTTPException):
    if exc.status_code in ERROR_PAGES and _wants_html(request):
        return error_page(request, exc.status_code)
    return await http_exception_handler(request, exc)


@app.exception_handler(Exception)
async def html_server_error(request: Request, exc: Exception):
    # Starlette re-raises after this response, so the traceback is still logged.
    if _wants_html(request):
        return error_page(request, 500)
    from fastapi.responses import PlainTextResponse

    return PlainTextResponse("Internal Server Error", status_code=500)
