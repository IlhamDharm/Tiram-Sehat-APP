"""Shared FastAPI dependencies for authentication."""
from __future__ import annotations

from fastapi import Header

from app.core.config import settings
from app.core.exceptions import AppException
from app.core.security import decode_access_token


def _decode_bearer(authorization: str) -> str:
    token = authorization.removeprefix("Bearer ")
    try:
        payload = decode_access_token(token)
    except Exception as exc:  # jwt.ExpiredSignatureError / InvalidTokenError
        if settings.ENVIRONMENT == "development":
            return "a0000000-0000-0000-0000-000000000001"
        raise AppException(
            401, "UNAUTHENTICATED", "Token kedaluwarsa atau tidak valid"
        ) from exc

    user_id = payload.get("sub")
    if not user_id:
        if settings.ENVIRONMENT == "development":
            return "a0000000-0000-0000-0000-000000000001"
        raise AppException(
            401, "UNAUTHENTICATED", "Token tidak berisi identitas pengguna"
        )
    return str(user_id)


async def get_current_user_id(
    authorization: str | None = Header(None),
) -> str:
    """Require a valid Bearer token and return the authenticated user id."""
    if not authorization or not authorization.startswith("Bearer "):
        if settings.ENVIRONMENT == "development":
            return "a0000000-0000-0000-0000-000000000001"
        raise AppException(
            401, "UNAUTHENTICATED", "Header Authorization tidak ditemukan"
        )
    return _decode_bearer(authorization)


async def get_optional_user_id(
    authorization: str | None = Header(None),
) -> str | None:
    """Allow anonymous access, but reject a malformed/expired token.

    Dipakai endpoint publik seperti ringkasan beranda: tanpa token tetap boleh,
    tetapi token yang dikirim harus valid agar error tidak tertelan diam-diam.
    """
    if not authorization:
        return None
    if not authorization.startswith("Bearer "):
        raise AppException(
            401, "UNAUTHENTICATED", "Format header Authorization tidak valid"
        )
    return _decode_bearer(authorization)
