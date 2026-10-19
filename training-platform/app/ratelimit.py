"""Small in-process sliding-window limiter for public forms. nginx limits
the same paths per IP as a backstop; this one answers with a friendly page
instead of nginx's bare 429."""
from __future__ import annotations

import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import Request

_hits: dict[tuple[str, str], deque] = defaultdict(deque)
_lock = Lock()


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def hit(bucket: str, request: Request, limit: int = 5, window: float = 600.0) -> bool:
    """Record one attempt; return True when the caller is over the limit."""
    key = (bucket, client_ip(request))
    now = time.monotonic()
    with _lock:
        q = _hits[key]
        while q and now - q[0] > window:
            q.popleft()
        if len(q) >= limit:
            return True
        q.append(now)
        return False


def reset() -> None:
    with _lock:
        _hits.clear()
