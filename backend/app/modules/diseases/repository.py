"""Disease repository — SQL queries for diseases and disease_steps."""
from __future__ import annotations

from typing import Any
from app.core.database import fetch_all, fetch_one


_ML_LABEL_ALIASES: dict[str, tuple[str, ...]] = {
    "blackmold": ("blackmold", "black_mold", "black_bread_mold"),
    "black_mold": ("black_mold", "blackmold", "black_bread_mold"),
    "black_bread_mold": ("black_bread_mold", "blackmold", "black_mold"),
    "greenmold": ("greenmold", "green_mold"),
    "green_mold": ("green_mold", "greenmold"),
    "healthy": ("healthy",),
}


async def find_by_ml_label(ml_label: str) -> dict[str, Any] | None:
    """Find a disease by its ML output label (with model-class aliases)."""
    normalized = (ml_label or "").strip().lower()
    candidates = list(_ML_LABEL_ALIASES.get(normalized, (normalized,)))
    return await fetch_one(
        "SELECT * FROM diseases WHERE LOWER(ml_label) = ANY(%(labels)s) AND is_active = TRUE LIMIT 1",
        {"labels": candidates},
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

