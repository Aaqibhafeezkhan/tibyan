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
PATTERNS = {
    "android": "*universal*.apk",
    "macos": "*macos*.zip",
    "windows": "*windows*.zip",
    "linux": "*linux*.tar.gz",
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
        for platform, pattern in PATTERNS.items():
            if platform in found:
                continue
            for asset in rel.get("assets") or []:
                name = asset.get("name") or ""
                url = asset.get("browser_download_url") or ""
                if fnmatch.fnmatch(name.lower(), pattern) and url.startswith("https://github.com/"):
                    found[platform] = {
                        "url": url,
                        "name": name,
                        "size": int(asset.get("size") or 0),
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
