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


async def find_existing_user(phone: str, farmer_id: str | None = None) -> dict | None:
    """Check whether phone or farmer_id is already registered."""
    if farmer_id:
        return await fetch_one(
            "SELECT id, phone, farmer_id FROM users WHERE phone = %(phone)s OR farmer_id = %(fid)s LIMIT 1",
            {"phone": phone, "fid": farmer_id},
        )
    return await fetch_one(
        "SELECT id, phone, farmer_id FROM users WHERE phone = %(phone)s LIMIT 1",
        {"phone": phone},
    )


async def create_user(
    conn: AsyncConnection,
    *,
    name: str,
    phone: str,
    pin_hash: str,
    farmer_id: str | None = None,
    kumbung_code: str = "A",
) -> dict:
    """Create a farmer account and assign default kumbung & preferences."""
    cur = await conn.execute(
        """
        INSERT INTO users (name, phone, farmer_id, pin_hash, role, is_active)
        VALUES (%(name)s, %(phone)s, %(farmer_id)s, %(pin_hash)s, 'farmer', TRUE)
        RETURNING id, name, phone, farmer_id, role, email, is_active
        """,
        {
            "name": name,
            "phone": phone,
            "farmer_id": farmer_id,
            "pin_hash": pin_hash,
        },
    )
    user = await cur.fetchone()
    assert user is not None
    user_id = str(user["id"])

    k_cur = await conn.execute(
        """
        SELECT id FROM kumbungs
        WHERE UPPER(code) = UPPER(%(code)s) AND is_active = TRUE
        LIMIT 1
        """,
        {"code": kumbung_code},
    )
    k_row = await k_cur.fetchone()
    if not k_row:
        k_cur = await conn.execute(
            "SELECT id FROM kumbungs WHERE is_active = TRUE ORDER BY code ASC LIMIT 1"
        )
        k_row = await k_cur.fetchone()

    kumbung_id = str(k_row["id"]) if k_row else None
    if kumbung_id:
        await conn.execute(
            """
            INSERT INTO user_kumbung_assignments (user_id, kumbung_id, is_primary)
            VALUES (%(uid)s, %(kid)s, TRUE)
            ON CONFLICT (user_id, kumbung_id) DO NOTHING
            """,
            {"uid": user_id, "kid": kumbung_id},
        )

    await conn.execute(
        """
        INSERT INTO user_preferences (user_id, active_kumbung_id, onboarding_completed)
        VALUES (%(uid)s, %(kid)s, TRUE)
        ON CONFLICT (user_id) DO NOTHING
        """,
        {"uid": user_id, "kid": kumbung_id},
    )

    return user  # type: ignore[return-value]


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
