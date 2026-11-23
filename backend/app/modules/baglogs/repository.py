"""Baglog repository — SQL queries for baglogs and baglog_batches."""
from __future__ import annotations

from datetime import datetime, timezone
from psycopg import AsyncConnection
from app.core.database import fetch_all, fetch_one


async def create_baglog(conn: AsyncConnection, data: dict) -> dict | None:
    cur = await conn.execute(
        """
        INSERT INTO baglogs (
            code, batch_id, rak_id, column_no, status, created_at, updated_at
        ) VALUES (
            %(code)s, %(batch_id)s, %(rak_id)s, %(column_no)s, %(status)s, %(now)s, %(now)s
        )
        RETURNING *
        """,
        {**data, "now": datetime.now(timezone.utc)},
    )
    return await cur.fetchone()


async def get_baglog_by_id(baglog_id: str) -> dict | None:
    return await fetch_one("SELECT * FROM baglogs WHERE id = %(id)s", {"id": baglog_id})


async def get_baglog_by_location(rak_id: str, column_no: int, batch_id: str | None = None) -> dict | None:
    if batch_id:
        return await fetch_one(
            "SELECT * FROM baglogs WHERE rak_id = %(rak_id)s AND column_no = %(column_no)s AND batch_id = %(batch_id)s",
            {"rak_id": rak_id, "column_no": column_no, "batch_id": batch_id},
        )
    return await fetch_one(
        "SELECT * FROM baglogs WHERE rak_id = %(rak_id)s AND column_no = %(column_no)s",
        {"rak_id": rak_id, "column_no": column_no},
    )


async def list_baglogs_by_rak(rak_id: str) -> list[dict]:
    return await fetch_all(
        "SELECT * FROM baglogs WHERE rak_id = %(rak_id)s ORDER BY column_no ASC",
        {"rak_id": rak_id},
    )


async def update_baglog_status(conn: AsyncConnection, baglog_id: str, status: str) -> dict | None:
    cur = await conn.execute(
        """
        UPDATE baglogs
        SET status = %(status)s,
            updated_at = %(now)s
        WHERE id = %(id)s
        RETURNING *
        """,
        {"id": baglog_id, "status": status, "now": datetime.now(timezone.utc)},
    )
    return await cur.fetchone()

