"""JWT access/refresh tokens and bcrypt PIN hashing."""
from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import uuid4

import bcrypt
import jwt

from app.core.config import settings


# ── PIN hashing (bcrypt) ────────────────────────────────────────────────────


def hash_pin(pin: str) -> str:
    """Hash a numeric PIN with bcrypt."""
    return bcrypt.hashpw(pin.encode(), bcrypt.gensalt(rounds=settings.PIN_HASH_ROUNDS)).decode()


def verify_pin(pin: str, hashed: str) -> bool:
    """Verify a PIN against a bcrypt hash."""
    return bcrypt.checkpw(pin.encode(), hashed.encode())


# ── JWT helpers ─────────────────────────────────────────────────────────────


def create_access_token(user_id: str, role: str, extra: dict[str, Any] | None = None) -> str:
    """Create a short-lived JWT access token."""
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": user_id,
        "role": role,
        "iat": now,
        "exp": now + timedelta(seconds=settings.JWT_ACCESS_TTL_SECONDS),
        "jti": uuid4().hex,
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.JWT_SECRET, algorithm="HS256")


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT access token.

    Raises ``jwt.ExpiredSignatureError`` or ``jwt.InvalidTokenError`` on failure.
    """
    return jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])


# ── Refresh token helpers ───────────────────────────────────────────────────


def generate_refresh_token() -> str:
    """Generate a cryptographically random refresh token string."""
    return f"rft_{secrets.token_urlsafe(48)}"


def hash_refresh_token(token: str) -> str:
    """SHA-256 hash of a refresh token (stored in DB, not the raw token)."""
    return hashlib.sha256(token.encode()).hexdigest()
