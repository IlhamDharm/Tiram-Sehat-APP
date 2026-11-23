"""Harvest repository — SQL queries for harvest_entries."""
from __future__ import annotations

from datetime import datetime, timezone
from psycopg import AsyncConnection
from app.core.database import fetch_all, fetch_one, get_connection


async def create_harvest(conn: AsyncConnection, data: dict) -> dict | None:
    cur = await conn.execute(
        """
        INSERT INTO harvest_entries (
            user_id, batch_id, kumbung_id, harvested_at, weight_kg, price_per_kg, gross_income, note, created_at, updated_at
        ) VALUES (
            %(user_id)s, %(batch_id)s, %(kumbung_id)s, %(harvested_at)s, %(weight_kg)s, %(price_per_kg)s, %(gross_income)s, %(note)s, %(now)s, %(now)s
        )
        RETURNING *
        """,
        {**data, "now": datetime.now(timezone.utc)},
    )
    return await cur.fetchone()


async def get_harvest_by_id(
    harvest_id: str, user_id: str | None = None
) -> dict | None:
    if user_id:
        return await fetch_one(
            "SELECT * FROM harvest_entries WHERE id = %(id)s AND user_id = %(user_id)s",
            {"id": harvest_id, "user_id": user_id},
        )
    return await fetch_one(
        "SELECT * FROM harvest_entries WHERE id = %(id)s", {"id": harvest_id}
    )


async def list_harvests(
    user_id: str | None = None,
    kumbung_id: str | None = None,
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = 20,
    cursor: str | None = None,
) -> list[dict]:
    conditions = []
    params: dict = {"limit": limit}

    if user_id:
        conditions.append("user_id = %(user_id)s")
        params["user_id"] = user_id
    if kumbung_id:
        conditions.append("kumbung_id = %(kumbung_id)s")
        params["kumbung_id"] = kumbung_id
    if from_date:
        conditions.append("harvested_at >= %(from_date)s")
        params["from_date"] = from_date
    if to_date:
        conditions.append("harvested_at <= %(to_date)s")
        params["to_date"] = to_date
    if cursor:
        conditions.append("harvested_at < %(cursor)s")
        params["cursor"] = cursor

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    query = f"""
        SELECT * FROM harvest_entries
        {where}
        ORDER BY harvested_at DESC
        LIMIT %(limit)s
    """
    return await fetch_all(query, params)


async def update_harvest(
    conn: AsyncConnection,
    harvest_id: str,
    data: dict,
    user_id: str | None = None,
) -> dict | None:
    sets = []
    params: dict = {"id": harvest_id, "now": datetime.now(timezone.utc)}
    for k, v in data.items():
        if v is not None:
            sets.append(f"{k} = %({k})s")
            params[k] = v
    sets.append("updated_at = %(now)s")

    query = f"""
        UPDATE harvest_entries
        SET {', '.join(sets)}
        WHERE id = %(id)s
          AND (%(user_id)s::uuid IS NULL OR user_id = %(user_id)s::uuid)
        RETURNING *
    """
    params["user_id"] = user_id
    cur = await conn.execute(query, params)
    return await cur.fetchone()


async def delete_harvest(
    conn: AsyncConnection, harvest_id: str, user_id: str | None = None
) -> int:
    cur = await conn.execute(
        """
        DELETE FROM harvest_entries
        WHERE id = %(id)s
          AND (%(user_id)s::uuid IS NULL OR user_id = %(user_id)s::uuid)
        """,
        {"id": harvest_id, "user_id": user_id},
    )
    return cur.rowcount

