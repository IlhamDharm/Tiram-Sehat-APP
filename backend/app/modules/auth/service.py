"""Auth service — login, refresh, logout business logic."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.core.config import settings
from app.core.database import get_connection
from app.core.exceptions import AppException
from app.core.security import (
    create_access_token,
    decode_access_token,
    generate_refresh_token,
    hash_pin,
    hash_refresh_token,
    verify_pin,
)
from app.modules.auth import repository as repo
from app.modules.auth.schemas import KumbungBrief, TokenResponse, UserBrief


async def _build_token_response(user: dict, ip: str | None = None, ua: str | None = None) -> dict:
    """Issue access + refresh tokens and build the response payload."""
    access = create_access_token(user["id"], user["role"])
    refresh = generate_refresh_token()
    refresh_hash = hash_refresh_token(refresh)
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=settings.REFRESH_TTL_SECONDS)

    async with get_connection() as conn:
        async with conn.transaction():
            await repo.save_refresh_token(conn, user["id"], refresh_hash, expires_at, ip, ua)

    kumbungs = await repo.get_user_kumbungs(user["id"])

    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        expires_in=settings.JWT_ACCESS_TTL_SECONDS,
        user=UserBrief(
            id=user["id"],
            name=user["name"],
            farmer_id=user.get("farmer_id"),
            role=user["role"],
            kumbungs=[
                KumbungBrief(id=k["id"], code=k["code"], name=k["name"], is_primary=k["is_primary"])
                for k in kumbungs
            ],
        ),
    ).model_dump()


async def login_with_pin(identifier: str, pin: str, ip: str | None = None, ua: str | None = None) -> dict:
    """Authenticate a user by phone/farmer_id + PIN."""
    user = await repo.find_user_by_identifier(identifier)
    if not user:
        raise AppException(401, "UNAUTHENTICATED", "Identifier atau PIN salah")
    if not verify_pin(pin, user["pin_hash"]):
        raise AppException(401, "UNAUTHENTICATED", "Identifier atau PIN salah")
    return await _build_token_response(user, ip, ua)


async def login_with_google(google_id: str, email: str, name: str, ip: str | None = None, ua: str | None = None) -> dict:
    """Find or create user from verified Google token claims, then issue tokens."""
    user = await repo.find_user_by_google_id(google_id)
    if not user:
        # Auto-create as farmer (PIN set to random, must reset later)
        raise AppException(404, "NOT_FOUND", "User belum terdaftar, hubungi admin")
    return await _build_token_response(user, ip, ua)


async def refresh_tokens(refresh_token: str, ip: str | None = None, ua: str | None = None) -> dict:
    """Rotate a refresh token and issue new access + refresh pair."""
    old_hash = hash_refresh_token(refresh_token)
    token_row = await repo.find_refresh_token(old_hash)
    if not token_row:
        raise AppException(401, "UNAUTHENTICATED", "Refresh token tidak valid atau kedaluwarsa")

    user = await repo.find_user_by_id(token_row["user_id"])
    if not user:
        raise AppException(401, "UNAUTHENTICATED", "User tidak ditemukan")

    # Revoke old token and issue new pair
    async with get_connection() as conn:
        async with conn.transaction():
            await repo.revoke_refresh_token(conn, old_hash)

    return await _build_token_response(user, ip, ua)


async def logout(refresh_token: str) -> None:
    """Revoke a refresh token."""
    token_hash = hash_refresh_token(refresh_token)
    async with get_connection() as conn:
        async with conn.transaction():
            await repo.revoke_refresh_token(conn, token_hash)


async def change_pin(user_id: str, current_pin: str, new_pin: str) -> None:
    """Change a user's PIN after verifying the current one."""
    user = await repo.find_user_by_id(user_id)
    if not user:
        raise AppException(404, "NOT_FOUND", "User tidak ditemukan")
    if not verify_pin(current_pin, user["pin_hash"]):
        raise AppException(401, "UNAUTHENTICATED", "PIN lama salah")
    new_hash = hash_pin(new_pin)
    async with get_connection() as conn:
        async with conn.transaction():
            await repo.update_user_pin(conn, user_id, new_hash)
