"""Disease repository — SQL queries for diseases and disease_steps."""
from __future__ import annotations

from typing import Any
from app.core.database import fetch_all, fetch_one


async def find_by_ml_label(ml_label: str) -> dict[str, Any] | None:
    """Find a disease by its ML output label."""
    return await fetch_one(
        "SELECT * FROM diseases WHERE ml_label = %(label)s AND is_active = TRUE",
        {"label": ml_label},
    )


async def find_by_id(disease_id: str) -> dict[str, Any] | None:
    """Find a disease by its UUID."""
    return await fetch_one(
        "SELECT * FROM diseases WHERE id = %(id)s::uuid",
        {"id": disease_id},
    )


async def list_all_active() -> list[dict[str, Any]]:
    """List all active diseases."""
    return await fetch_all(
        "SELECT * FROM diseases WHERE is_active = TRUE ORDER BY name ASC"
    )

