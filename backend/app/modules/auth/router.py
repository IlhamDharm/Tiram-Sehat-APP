"""Auth router — login, refresh, logout, change PIN."""
from __future__ import annotations

from fastapi import APIRouter, Header, Request

from app.core.exceptions import success_response
from app.modules.auth import service
from app.modules.auth.schemas import (
    ChangePinRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
)

router = APIRouter()


def _client_ip(request: Request) -> str | None:
    return request.client.host if request.client else None


@router.post("/login")
async def login(body: LoginRequest, request: Request):
    """Authenticate with phone/farmer_id + PIN."""
    data = await service.login_with_pin(
        body.identifier, body.pin,
        ip=_client_ip(request),
        ua=request.headers.get("user-agent"),
    )
    return success_response(data)


@router.post("/refresh")
async def refresh(body: RefreshRequest, request: Request):
    """Rotate refresh token and get new access + refresh pair."""
    data = await service.refresh_tokens(
        body.refresh_token,
        ip=_client_ip(request),
        ua=request.headers.get("user-agent"),
    )
    return success_response(data)


@router.post("/logout")
async def logout(body: LogoutRequest):
    """Revoke a refresh token."""
    await service.logout(body.refresh_token)
    return success_response({"message": "Logged out"})


@router.patch("/pin")
async def change_pin(
    body: ChangePinRequest,
    authorization: str = Header(...),
):
    """Change the current user's PIN."""
    from app.core.security import decode_access_token

    token = authorization.removeprefix("Bearer ")
    payload = decode_access_token(token)
    await service.change_pin(payload["sub"], body.current_pin, body.new_pin)
    return success_response({"message": "PIN berhasil diubah"})
