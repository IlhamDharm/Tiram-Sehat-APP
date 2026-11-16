"""Upload service — sign, verify, and perform Cloudinary uploads."""
from __future__ import annotations

import asyncio

import cloudinary
import cloudinary.uploader

from app.core.cloudinary import build_thumbnail_url, sign_upload
from app.core.config import settings
from app.core.exceptions import AppException

ALLOWED_TYPES = {"scan", "avatar", "batch"}
ALLOWED_MIMES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
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


def _configure_cloudinary() -> None:
    if not (
        settings.CLOUDINARY_CLOUD_NAME
        and settings.CLOUDINARY_API_KEY
        and settings.CLOUDINARY_API_SECRET
    ):
        raise AppException(
            500,
            "CLOUDINARY_CONFIG_ERROR",
            "Konfigurasi Cloudinary di .env belum lengkap",
        )
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True,
    )


async def upload_image_bytes(
    contents: bytes,
    filename: str,
    content_type: str,
    upload_type: str = "scan",
) -> dict:
    """Validate and upload image bytes directly to Cloudinary."""
    if upload_type not in ALLOWED_TYPES:
        raise AppException(400, "VALIDATION_ERROR", f"Upload type '{upload_type}' tidak valid")

    lower_name = (filename or "").lower()
    is_valid_mime = content_type in ALLOWED_MIMES or content_type.startswith("image/")
    is_valid_ext = any(lower_name.endswith(ext) for ext in ALLOWED_EXTENSIONS)
    if not (is_valid_mime or is_valid_ext):
        raise AppException(
            400,
            "VALIDATION_ERROR",
            f"File harus berupa gambar (jpg/png/webp). Diterima: {content_type}",
        )

    if not contents:
        raise AppException(400, "VALIDATION_ERROR", "File gambar kosong")
    if len(contents) > MAX_SIZE:
        raise AppException(400, "VALIDATION_ERROR", "Ukuran file melebihi 10 MB")

    _configure_cloudinary()
    folder = f"{settings.CLOUDINARY_FOLDER}/{upload_type}s"

    try:
        result = await asyncio.to_thread(
            cloudinary.uploader.upload,
            contents,
            folder=folder,
            resource_type="image",
        )
    except Exception as exc:
        raise AppException(
            502,
            "UPLOAD_FAILED",
            f"Gagal mengunggah gambar ke Cloudinary: {exc}",
        ) from exc

    image_url = result.get("secure_url") or result.get("url")
    public_id = result.get("public_id")
    version = result.get("version")
    if not image_url:
        raise AppException(502, "UPLOAD_FAILED", "Cloudinary tidak mengembalikan URL gambar")

    thumbnail_url = build_thumbnail_url(public_id) if public_id else image_url

    return {
        "image_url": image_url,
        "image_public_id": public_id,
        "image_version": version,
        "image_thumbnail_url": thumbnail_url,
    }
