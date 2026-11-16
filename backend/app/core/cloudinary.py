"""Cloudinary helpers – upload signature and image URL builders."""
from __future__ import annotations

import hashlib
import time
from uuid import uuid4

from app.core.config import settings


def _sign(params: dict[str, str | int]) -> str:
    """Generate a Cloudinary SHA-1 signature for the given parameters."""
    to_sign = "&".join(f"{k}={params[k]}" for k in sorted(params))
    return hashlib.sha1(
        (to_sign + settings.CLOUDINARY_API_SECRET).encode()
    ).hexdigest()


def sign_upload(upload_type: str = "scan", user_id: str = "") -> dict:
    """Return a signed upload payload the client sends to Cloudinary.

    ``upload_type`` — one of ``scan``, ``avatar``, ``batch``.
    ``user_id`` — current user id (used in the ``public_id``).
    """
    timestamp = int(time.time())
    year = time.strftime("%Y")
    month = time.strftime("%m")
    folder = f"{settings.CLOUDINARY_FOLDER}/{upload_type}s/{year}/{month}"
    public_id = f"{folder}/{upload_type}_{user_id}_{uuid4().hex[:12]}"

    params: dict[str, str | int] = {
        "folder": folder,
        "public_id": public_id,
        "timestamp": timestamp,
    }

    return {
        "cloud_name": settings.CLOUDINARY_CLOUD_NAME,
        "api_key": settings.CLOUDINARY_API_KEY,
        "upload_preset": settings.CLOUDINARY_UPLOAD_PRESET,
        "folder": folder,
        "public_id": public_id,
        "timestamp": timestamp,
        "signature": _sign(params),
        "expires_at": timestamp + 300,  # 5 minutes
    }


def build_image_url(public_id: str, transforms: str = "q_auto,f_webp") -> str:
    """Build a Cloudinary delivery URL with optional transforms."""
    base = f"https://res.cloudinary.com/{settings.CLOUDINARY_CLOUD_NAME}/image/upload"
    if transforms:
        return f"{base}/{transforms}/{public_id}"
    return f"{base}/{public_id}"


def build_thumbnail_url(public_id: str, width: int = 400) -> str:
    """Build a thumbnail URL with width resize + quality/format auto."""
    return build_image_url(public_id, f"w_{width},q_auto,f_webp")
