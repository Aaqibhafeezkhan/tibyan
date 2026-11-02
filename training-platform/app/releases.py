"""Latest beta downloads from GitHub releases (helalrules7/tibyan).

The newest release is often a prerelease, so /releases/latest/download
doesn't work; we ask the API (unauthenticated) and cache the answer."""
from __future__ import annotations

import fnmatch
import json
import threading
import time
import urllib.request

API_URL = "https://api.github.com/repos/helalrules7/tibyan/releases?per_page=5"
RELEASES_PAGE = "https://github.com/helalrules7/tibyan/releases"
CACHE_TTL = 600  # seconds
FAIL_TTL = 60  # retry a failed fetch after a minute, not on every request
# Each platform: glob patterns in order of preference within one release.
# Releases ship per-ABI APKs (flutter build apk --split-per-abi); /download/android
# gives arm64-v8a (nearly every phone), falling back to a universal APK for
# releases that have no split. The other ABIs keep their own links.
PATTERNS = {
    "android": ("*arm64-v8a*.apk", "*universal*.apk"),
    "android-armeabi-v7a": ("*armeabi-v7a*.apk",),
    "android-x86_64": ("*x86_64*.apk",),
    "android-universal": ("*universal*.apk",),
    "macos": ("*macos*.zip",),
    "windows": ("*windows*.zip",),
    "linux": ("*linux*.tar.gz",),
}

_now = time.monotonic  # patched in tests
_lock = threading.Lock()
_cache: dict = {"at": 0.0, "ttl": 0, "data": {}}


def _fetch() -> list:
    req = urllib.request.Request(
        API_URL,
        headers={"Accept": "application/vnd.github+json", "User-Agent": "altibyan.app"},
    )
    with urllib.request.urlopen(req, timeout=4) as resp:
        return json.load(resp)


def _pick(releases: list) -> dict:
    """platform -> {url, name, size, version} from the newest release
    (prereleases included, drafts skipped) that has a matching asset."""
    found: dict = {}
    for rel in releases:
        if not isinstance(rel, dict) or rel.get("draft"):
            continue
        assets = rel.get("assets") or []
        for platform, patterns in PATTERNS.items():
            if platform in found:
                continue
            for pattern in patterns:
                hit = next(
                    (
                        a
                        for a in assets
                        if fnmatch.fnmatch((a.get("name") or "").lower(), pattern)
                        and (a.get("browser_download_url") or "").startswith("https://github.com/")
                    ),
                    None,
                )
                if hit:
                    found[platform] = {
                        "url": hit["browser_download_url"],
                        "name": hit.get("name") or "",
                        "size": int(hit.get("size") or 0),
                        "version": (rel.get("tag_name") or "").lstrip("v"),
                    }
                    break
    return found


def downloads() -> dict:
    now = _now()
    with _lock:
        if _cache["at"] and now - _cache["at"] < _cache["ttl"]:
            return _cache["data"]
    try:
        data = _pick(_fetch())
        ttl = CACHE_TTL
    except Exception:  # network/API/JSON failure: fall back, keep old data
        with _lock:
            data = _cache["data"]
        ttl = FAIL_TTL
    with _lock:
        _cache.update(at=now, ttl=ttl, data=data)
    return data


def download_url(platform: str) -> str:
    item = downloads().get(platform)
    return item["url"] if item else RELEASES_PAGE


def human_size(size: int, ar: bool) -> str:
    if size <= 0:
        return ""
    mb = size / 1_000_000
    return f"{mb:.0f} {'ميجابايت' if ar else 'MB'}"


def reset() -> None:
    with _lock:
        _cache.update(at=0.0, ttl=0, data={})
