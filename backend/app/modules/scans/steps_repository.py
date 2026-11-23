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


async def get_steps_for_scan_ids(scan_ids: list[str]) -> dict[str, list[dict]]:
    """Batch fetch treatment steps for multiple scans in a single query."""
    if not scan_ids:
        return {}
    rows = await fetch_all(
        """
        SELECT scan_id::text AS scan_id, step_order, title, description
        FROM scan_steps
        WHERE scan_id = ANY(%(scan_ids)s::uuid[])
        ORDER BY scan_id, step_order ASC
        """,
        {"scan_ids": scan_ids},
    )
    grouped: dict[str, list[dict]] = {}
    for row in rows:
        sid = str(row["scan_id"])
        grouped.setdefault(sid, []).append(
            {
                "step_order": row["step_order"],
                "title": row["title"],
                "description": row["description"],
            }
        )
    return grouped


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


async def insert_custom_steps(conn: AsyncConnection, scan_id: str, steps: list[dict]) -> None:
    """Insert custom treatment steps for a scan when no disease_steps were copied."""
    for idx, step in enumerate(steps, start=1):
        await conn.execute(
            """
            INSERT INTO scan_steps (scan_id, step_order, title, description)
            VALUES (%(scan_id)s, %(step_order)s, %(title)s, %(description)s)
            ON CONFLICT (scan_id, step_order) DO NOTHING
            """,
            {
                "scan_id": scan_id,
                "step_order": idx,
                "title": step["title"],
                "description": step.get("description", ""),
            },
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
