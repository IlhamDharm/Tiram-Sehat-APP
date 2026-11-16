"""Async HTTP client for the Hugging Face Space ML inference endpoint."""
from __future__ import annotations

import logging
from typing import Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


async def predict_from_url(image_url: str) -> dict[str, Any]:
    """Call the HF Space ``/predict`` endpoint with an image URL.

    Returns the parsed JSON body on success.  Retries up to
    ``settings.HF_MAX_RETRIES`` times on transient failures.
    """
    payload = {"image_url": image_url}
    headers: dict[str, str] = {}
    if settings.HF_INTERNAL_SECRET:
        headers["Authorization"] = f"Bearer {settings.HF_INTERNAL_SECRET}"

    last_exc: Exception | None = None

    for attempt in range(1, settings.HF_MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(settings.HF_TIMEOUT_SECONDS)
            ) as client:
                resp = await client.post(
                    f"{settings.HF_SPACE_URL.rstrip('/')}/predict",
                    json=payload,
                    headers=headers,
                )
                resp.raise_for_status()
                data: dict[str, Any] = resp.json()
                return data
        except (httpx.HTTPStatusError, httpx.TransportError) as exc:
            last_exc = exc
            logger.warning(
                "ML predict attempt %d/%d failed: %s",
                attempt,
                settings.HF_MAX_RETRIES,
                exc,
            )

    raise RuntimeError(
        f"ML inference failed after {settings.HF_MAX_RETRIES} attempts"
    ) from last_exc
