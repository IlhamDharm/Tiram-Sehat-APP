"""ML inference client — prefers local TFLite model, falls back to HF Space."""
from __future__ import annotations

import logging
from typing import Any

import httpx

from app.core.config import settings
from app.core.tflite_model import (
    PredictionResult,
    predict_image_bytes_async,
    resolve_model_path,
)

logger = logging.getLogger(__name__)


async def predict_from_url(image_url: str) -> PredictionResult:
    """Predict disease label from ``image_url`` using local TFLite or HF Space."""
    if resolve_model_path().exists():
        try:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(settings.HF_TIMEOUT_SECONDS),
                follow_redirects=True,
            ) as client:
                resp = await client.get(image_url)
                resp.raise_for_status()
            return await predict_image_bytes_async(resp.content)
        except Exception as exc:
            if not settings.HF_SPACE_URL:
                raise RuntimeError(
                    f"Local TFLite inference failed for image URL: {exc}"
                ) from exc
            logger.warning(
                "Local TFLite URL inference failed (%s), falling back to HF Space",
                exc,
            )

    if not settings.HF_SPACE_URL:
        raise RuntimeError(
            "Local TFLite model not found and HF_SPACE_URL is not configured"
        )

    payload = {"image_url": image_url}
    headers: dict[str, str] = {}
    if settings.HF_INTERNAL_SECRET:
        headers["Authorization"] = f"Bearer {settings.HF_INTERNAL_SECRET}"
        headers["X-Internal-Secret"] = settings.HF_INTERNAL_SECRET

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
                label = str(data.get("label") or "greenmold")
                confidence = max(0.0, min(1.0, float(data.get("confidence") or 0.0)))
                return PredictionResult(
                    label=label,
                    confidence=confidence,
                    probabilities=data.get("probabilities") or {label: confidence},
                    model_version=str(
                        data.get("model_version") or settings.ML_MODEL_VERSION
                    ),
                )
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
