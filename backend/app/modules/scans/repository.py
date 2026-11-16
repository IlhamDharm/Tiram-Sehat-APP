"""Scan repository — SQL queries for scans table."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from psycopg import AsyncConnection

from app.core.database import fetch_all, fetch_one, get_connection


async def create_scan(conn: AsyncConnection, data: dict) -> dict | None:
    """Insert a new scan row and return it."""
    cur = await conn.execute(
        """
        INSERT INTO scans (
            user_id, rak_id, column_no, batch_id,
            disease_id, diagnosis_name, scientific_name,
            confidence, infection_location, severity,
            scan_method, image_public_id, image_url,
            image_version, image_thumbnail_url,
            status, scanned_at, inference_status
        ) VALUES (
            %(user_id)s, %(rak_id)s, %(column_no)s, %(batch_id)s,
            %(disease_id)s, %(diagnosis_name)s, %(scientific_name)s,
            %(confidence)s, %(infection_location)s, %(severity)s,
            %(scan_method)s, %(image_public_id)s, %(image_url)s,
            %(image_version)s, %(image_thumbnail_url)s,
            %(status)s, %(scanned_at)s, %(inference_status)s
        )
        RETURNING *
        """,
        data,
    )
    return await cur.fetchone()  # type: ignore[return-value]


async def mark_processing(scan_id: str, attempt: int) -> None:
    async with get_connection() as conn:
        await conn.execute(
            """
            UPDATE scans
            SET inference_status = 'processing',
                inference_attempts = %(attempt)s,
                inference_started_at = %(now)s
            WHERE id = %(id)s
            """,
            {"id": scan_id, "attempt": attempt, "now": datetime.now(timezone.utc)},
        )


async def complete_inference(conn: AsyncConnection, scan_id: str, data: dict) -> dict | None:
    cur = await conn.execute(
        """
        UPDATE scans
        SET ml_label = %(ml_label)s,
            disease_id = %(disease_id)s,
            diagnosis_name = %(diagnosis_name)s,
            scientific_name = %(scientific_name)s,
            infection_location = %(infection_location)s,
            severity = %(severity)s,
            confidence = %(confidence)s,
            model_version = %(model_version)s,
            raw_response = %(raw_response)s,
            status = %(status)s,
            inference_status = 'completed',
            inference_completed_at = %(now)s
        WHERE id = %(id)s
        RETURNING *
        """,
        {"id": scan_id, "now": datetime.now(timezone.utc), **data},
    )
    return await cur.fetchone()  # type: ignore[return-value]


async def mark_failed(scan_id: str, error_message: str) -> None:
    async with get_connection() as conn:
        await conn.execute(
            """
            UPDATE scans
            SET inference_status = 'failed',
                inference_error = %(error)s
            WHERE id = %(id)s
            """,
            {"id": scan_id, "error": error_message},
        )


async def get_scan_by_id(scan_id: str, user_id: str | None = None) -> dict | None:
    if user_id:
        return await fetch_one(
            "SELECT * FROM scans WHERE id = %(id)s AND user_id = %(user_id)s",
            {"id": scan_id, "user_id": user_id},
        )
    return await fetch_one("SELECT * FROM scans WHERE id = %(id)s", {"id": scan_id})


async def list_scans(
    user_id: str,
    status: str | None = None,
    rak_id: str | None = None,
    disease_id: str | None = None,
    limit: int = 20,
    cursor: str | None = None,
) -> list[dict]:
    """List scans with optional filters, cursor-paginated."""
    conditions = ["s.user_id = %(user_id)s"]
    params: dict = {"user_id": user_id, "limit": limit}

    if status:
        conditions.append("s.status = %(status)s")
        params["status"] = status
    if rak_id:
        conditions.append("s.rak_id = %(rak_id)s")
        params["rak_id"] = rak_id
    if disease_id:
        conditions.append("s.disease_id = %(disease_id)s")
        params["disease_id"] = disease_id
    if cursor:
        conditions.append("s.scanned_at < %(cursor)s")
        params["cursor"] = cursor

    where = " AND ".join(conditions)
    query = f"""
        SELECT s.*, r.code as rak_code
        FROM scans s
        LEFT JOIN raks r ON r.id = s.rak_id
        WHERE {where}
        ORDER BY s.scanned_at DESC
        LIMIT %(limit)s
    """
    return await fetch_all(query, params)


async def update_scan_status(
    conn: AsyncConnection,
    scan_id: str,
    status: str,
    note: str | None,
    tag: str | None,
    user_id: str | None = None,
) -> dict | None:
    cur = await conn.execute(
        """
        UPDATE scans
        SET status = %(status)s,
            status_note = %(note)s,
            status_tag = %(tag)s,
            updated_at = %(now)s
        WHERE id = %(id)s
          AND (%(user_id)s::uuid IS NULL OR user_id = %(user_id)s::uuid)
        RETURNING *
        """,
        {
            "id": scan_id,
            "status": status,
            "note": note,
            "tag": tag,
            "now": datetime.now(timezone.utc),
            "user_id": user_id,
        },
    )
    return await cur.fetchone()  # type: ignore[return-value]


async def create_treatment_log(conn: AsyncConnection, log_data: dict) -> dict | None:
    cur = await conn.execute(
        """
        INSERT INTO treatment_logs (
            scan_id, action_type, from_status, to_status, note, tag, performed_by, performed_at, created_at
        ) VALUES (
            %(scan_id)s, %(action_type)s, %(from_status)s, %(to_status)s, %(note)s, %(tag)s, %(performed_by)s, %(performed_at)s, %(created_at)s
        )
        RETURNING *
        """,
        log_data,
    )
    return await cur.fetchone()  # type: ignore[return-value]


async def delete_scan(
    conn: AsyncConnection, scan_id: str, user_id: str | None = None
) -> int:
    cur = await conn.execute(
        """
        DELETE FROM scans
        WHERE id = %(id)s
          AND (%(user_id)s::uuid IS NULL OR user_id = %(user_id)s::uuid)
        """,
        {"id": scan_id, "user_id": user_id},
    )
    return cur.rowcount  # type: ignore[return-value]
