import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request, status

# In-memory sliding-window limiter, keyed per (bucket, client IP).
# Single-process only — fine for one uvicorn worker, but resets on restart
# and doesn't share state across workers/replicas. Swap for a Redis-backed
# limiter (e.g. slowapi + redis) before running multiple processes.
_hits: dict[str, deque] = defaultdict(deque)


def rate_limit(bucket: str, limit: int, window_seconds: int):
    def dependency(request: Request):
        client_ip = request.client.host if request.client else "unknown"
        key = f"{bucket}:{client_ip}"
        now = time.monotonic()
        hits = _hits[key]

        while hits and now - hits[0] > window_seconds:
            hits.popleft()

        if len(hits) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests, please try again later."
            )

        hits.append(now)

    return dependency
