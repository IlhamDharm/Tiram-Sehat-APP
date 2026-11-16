"""Auth schemas — request / response models."""
from __future__ import annotations

from pydantic import BaseModel, Field


# ── Requests ────────────────────────────────────────────────────────────────


class LoginRequest(BaseModel):
    identifier: str = Field(..., description="Phone number or farmer_id")
    pin: str = Field(..., min_length=4, max_length=8)


class GoogleLoginRequest(BaseModel):
    id_token: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class ChangePinRequest(BaseModel):
    current_pin: str = Field(..., min_length=4, max_length=8)
    new_pin: str = Field(..., min_length=4, max_length=8)


# ── Responses ───────────────────────────────────────────────────────────────


class KumbungBrief(BaseModel):
    id: str
    code: str
    name: str
    is_primary: bool


class UserBrief(BaseModel):
    id: str
    name: str
    farmer_id: str | None = None
    role: str
    kumbungs: list[KumbungBrief] = []


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    user: UserBrief
