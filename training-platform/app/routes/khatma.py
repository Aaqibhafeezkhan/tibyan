"""«الختمة الجماعية»: JSON API for the app, the shared page /k/<id>, and
the universal-link / app-link association files.

No CORS headers are sent: the app calls the API natively and the web page
is same-origin, so browsers on other sites cannot read or write it.
Secrets travel in the X-Khatma-Secret header, never in a URL."""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Header, Request
from fastapi.responses import JSONResponse, Response
from sqlalchemy.orm import Session

from .. import group_khatma as gk
from .. import ratelimit
from ..deps import get_db
from ..web import render

router = APIRouter()

APPLE_APP_ID = "T958VWM76Z.app.tibyan.tibyan"
ANDROID_PACKAGE = "app.tibyan.tibyan"
# SHA-256 of the signing certificates: the upload key, and Google Play's
# app signing key (Play Console > App integrity) when it differs.
ANDROID_CERTS: list[str] = [
    # Google Play app signing key (the Play build).
    "68:7B:5B:19:FE:7A:AF:A6:0B:6D:96:0F:67:3C:73:20:AF:33:3D:9A:AC:9E:2A:78:B2:D8:D7:F4:FF:4F:55:EE",
    # Upload key (the APK on /beta and GitHub releases).
    "86:80:1F:B8:7F:18:31:FC:5D:52:F5:F7:DB:3E:DF:A6:0B:A2:10:E5:A1:CA:5A:95:79:E9:8E:F8:CC:07:76:D4",
]


def _error(exc: gk.KhatmaError) -> JSONResponse:
    return JSONResponse(
        {"error": exc.code}, status_code=exc.status, headers={"Cache-Control": "no-store"}
    )


def _ok(body: dict, status: int = 200) -> JSONResponse:
    return JSONResponse(body, status_code=status, headers={"Cache-Control": "no-store"})


async def _body(request: Request) -> dict:
    raw = await request.body()
    if len(raw) > 4096:
        raise gk.KhatmaError(413, "too_large")
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except ValueError as exc:
        raise gk.KhatmaError(400, "bad_json") from exc
    if not isinstance(data, dict):
        raise gk.KhatmaError(400, "bad_json")
    return data


def _limited(bucket: str, request: Request, limit: int, window: float) -> bool:
    return ratelimit.hit(bucket, request, limit=limit, window=window)


@router.post("/api/k")
async def create_khatma(request: Request, db: Session = Depends(get_db)):
    if _limited("gk_create", request, 10, 3600):
        return _error(gk.KhatmaError(429, "rate_limited"))
    try:
        gk.maybe_cleanup(db)
        k, secret = gk.create(db, await _body(request))
        return _ok({"organizer_secret": secret, "khatma": gk.public(db, k)}, 201)
    except gk.KhatmaError as exc:
        return _error(exc)


@router.get("/api/k/{khatma_id}")
def get_khatma(khatma_id: str, db: Session = Depends(get_db)):
    try:
        gk.maybe_cleanup(db)
        return _ok(gk.public(db, gk.load(db, khatma_id)))
    except gk.KhatmaError as exc:
        return _error(exc)


@router.patch("/api/k/{khatma_id}")
async def rename_khatma(
    khatma_id: str,
    request: Request,
    db: Session = Depends(get_db),
    x_khatma_secret: str | None = Header(None),
):
    try:
        k = gk.load(db, khatma_id)
        gk.rename(db, k, x_khatma_secret, (await _body(request)).get("title"))
        return _ok(gk.public(db, k))
    except gk.KhatmaError as exc:
        return _error(exc)


@router.delete("/api/k/{khatma_id}")
def delete_khatma(
    khatma_id: str,
    db: Session = Depends(get_db),
    x_khatma_secret: str | None = Header(None),
):
    try:
        gk.delete(db, gk.load(db, khatma_id), x_khatma_secret)
        return Response(status_code=204)
    except gk.KhatmaError as exc:
        return _error(exc)


@router.post("/api/k/{khatma_id}/parts/{number}/claim")
async def claim_part(
    khatma_id: str, number: int, request: Request, db: Session = Depends(get_db)
):
    if _limited("gk_claim", request, 30, 600):
        return _error(gk.KhatmaError(429, "rate_limited"))
    try:
        k = gk.load(db, khatma_id)
        secret = gk.claim(db, k, number, (await _body(request)).get("name"))
        return _ok({"part_secret": secret, "khatma": gk.public(db, k)})
    except gk.KhatmaError as exc:
        return _error(exc)


def _part_action(action):
    def endpoint(
        khatma_id: str,
        number: int,
        request: Request,
        db: Session = Depends(get_db),
        x_khatma_secret: str | None = Header(None),
    ):
        if _limited("gk_part", request, 120, 600):
            return _error(gk.KhatmaError(429, "rate_limited"))
        try:
            k = gk.load(db, khatma_id)
            action(db, k, number, x_khatma_secret)
            return _ok(gk.public(db, k))
        except gk.KhatmaError as exc:
            return _error(exc)

    return endpoint


router.add_api_route(
    "/api/k/{khatma_id}/parts/{number}/done", _part_action(gk.mark_done), methods=["POST"]
)
router.add_api_route(
    "/api/k/{khatma_id}/parts/{number}/undone", _part_action(gk.undo_done), methods=["POST"]
)
router.add_api_route(
    "/api/k/{khatma_id}/parts/{number}/release", _part_action(gk.release), methods=["POST"]
)


@router.get("/k/{khatma_id}")
def khatma_page(khatma_id: str, request: Request, db: Session = Depends(get_db)):
    """The shared link. With the app installed the OS opens the app
    instead (universal / app links); otherwise this page."""
    try:
        state = gk.public(db, gk.load(db, khatma_id))
    except gk.KhatmaError:
        state = None
    lang = request.query_params.get("lang")
    extra = {"lang": lang, "dir": "rtl" if lang == "ar" else "ltr"} if lang in ("ar", "en") else {}
    response = render(
        request,
        "khatma.html",
        khatma=state,
        khatma_id=khatma_id,
        **extra,
    )
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Robots-Tag"] = "noindex"
    response.headers["Referrer-Policy"] = "no-referrer"
    if state is None:
        response.status_code = 404
    return response


@router.get("/.well-known/apple-app-site-association")
@router.get("/apple-app-site-association")
def apple_app_site_association():
    body = {
        "applinks": {
            "details": [
                {
                    "appIDs": [APPLE_APP_ID],
                    "components": [{"/": "/k/*", "comment": "Group khatma"}],
                }
            ]
        }
    }
    return JSONResponse(body, headers={"Cache-Control": "public, max-age=3600"})


@router.get("/.well-known/assetlinks.json")
def assetlinks():
    body = [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": ANDROID_PACKAGE,
                "sha256_cert_fingerprints": ANDROID_CERTS,
            },
        }
    ]
    return JSONResponse(body, headers={"Cache-Control": "public, max-age=3600"})
