"""Scan steps repository — SQL queries for scan_steps table."""
from __future__ import annotations

from psycopg import AsyncConnection

from app.core.database import fetch_all


async def get_steps_for_scan(scan_id: str) -> list[dict]:
    """Get all treatment steps for a scan, ordered."""
    return await fetch_all(
        """
        SELECT step_order, title, description
        FROM scan_steps
        WHERE scan_id = %(scan_id)s
        ORDER BY step_order ASC
        """,
        {"scan_id": scan_id},
    )


async def copy_disease_steps_to_scan(conn: AsyncConnection, scan_id: str, disease_id: str) -> None:
    """Copy disease_steps rows into scan_steps for a newly created scan."""
    await conn.execute(
        """
        INSERT INTO scan_steps (scan_id, step_order, title, description)
        SELECT %(scan_id)s, step_order, title, description
        FROM disease_steps
        WHERE disease_id = %(disease_id)s
        ORDER BY step_order
        """,
        {"scan_id": scan_id, "disease_id": disease_id},
    )


async def get_disease_steps(disease_id: str) -> list[dict]:
    """Get steps for a disease."""
    return await fetch_all(
        """
        SELECT step_order, title, description
        FROM disease_steps
        WHERE disease_id = %(disease_id)s
        ORDER BY step_order ASC
        """,
        {"disease_id": disease_id},
    )
