"""Auth repository — user and refresh-token DB queries."""
from __future__ import annotations

from datetime import datetime, timezone

from psycopg import AsyncConnection

from app.core.database import fetch_one, get_connection


async def find_user_by_identifier(identifier: str) -> dict | None:
    """Find a user by phone number or farmer_id."""
    return await fetch_one(
        """
        SELECT id, name, phone, farmer_id, pin_hash, role, email,
               google_id, avatar_url, is_active
        FROM users
        WHERE (phone = %(id)s OR farmer_id = %(id)s) AND is_active = TRUE
        """,
        {"id": identifier},
    )


async def find_user_by_google_id(google_id: str) -> dict | None:
    return await fetch_one(
        "SELECT * FROM users WHERE google_id = %(gid)s AND is_active = TRUE",
        {"gid": google_id},
    )


async def find_user_by_id(user_id: str) -> dict | None:
    return await fetch_one(
        "SELECT * FROM users WHERE id = %(uid)s AND is_active = TRUE",
        {"uid": user_id},
    )


async def get_user_kumbungs(user_id: str) -> list[dict]:
    """Return kumbungs assigned to the user."""
    async with get_connection() as conn:
        cur = await conn.execute(
            """
            SELECT k.id, k.code, k.name, uka.is_primary
            FROM user_kumbung_assignments uka
            JOIN kumbungs k ON k.id = uka.kumbung_id
            WHERE uka.user_id = %(uid)s AND k.is_active = TRUE
            """,
            {"uid": user_id},
        )
        return await cur.fetchall()  # type: ignore[return-value]


async def save_refresh_token(
    conn: AsyncConnection,
    user_id: str,
    token_hash: str,
    expires_at: datetime,
    ip: str | None = None,
    user_agent: str | None = None,
) -> None:
    await conn.execute(
        """
        INSERT INTO refresh_tokens (user_id, token_hash, expires_at, ip, user_agent)
        VALUES (%(uid)s, %(hash)s, %(exp)s, %(ip)s, %(ua)s)
        """,
        {
            "uid": user_id,
            "hash": token_hash,
            "exp": expires_at,
            "ip": ip,
            "ua": user_agent,
        },
    )


async def find_refresh_token(token_hash: str) -> dict | None:
    return await fetch_one(
        """
        SELECT * FROM refresh_tokens
        WHERE token_hash = %(hash)s AND revoked_at IS NULL AND expires_at > %(now)s
        """,
        {"hash": token_hash, "now": datetime.now(timezone.utc)},
    )


async def revoke_refresh_token(conn: AsyncConnection, token_hash: str) -> None:
    await conn.execute(
        """
        UPDATE refresh_tokens SET revoked_at = %(now)s
        WHERE token_hash = %(hash)s
        """,
        {"hash": token_hash, "now": datetime.now(timezone.utc)},
    )


async def update_user_pin(conn: AsyncConnection, user_id: str, new_pin_hash: str) -> None:
    await conn.execute(
        """
        UPDATE users SET pin_hash = %(pin)s, updated_at = %(now)s
        WHERE id = %(uid)s
        """,
        {"pin": new_pin_hash, "now": datetime.now(timezone.utc), "uid": user_id},
    )
