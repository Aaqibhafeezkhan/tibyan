from __future__ import annotations

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
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
from .templating import STATIC_DIR

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
