"""Upload service — sign and verify Cloudinary uploads."""
from __future__ import annotations

from app.core.cloudinary import sign_upload
from app.core.exceptions import AppException


ALLOWED_TYPES = {"scan", "avatar", "batch"}
ALLOWED_MIMES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE = 10 * 1024 * 1024  # 10 MB


def get_upload_signature(upload_type: str, content_type: str, size: int, user_id: str) -> dict:
    """Validate constraints and return a signed upload payload."""
    if upload_type not in ALLOWED_TYPES:
        raise AppException(400, "VALIDATION_ERROR", f"Upload type '{upload_type}' tidak valid")
    if content_type not in ALLOWED_MIMES:
        raise AppException(400, "VALIDATION_ERROR", f"Content type '{content_type}' tidak diizinkan")
    if size > MAX_SIZE:
        raise AppException(400, "VALIDATION_ERROR", "Ukuran file melebihi 10 MB")

    return sign_upload(upload_type, user_id)
