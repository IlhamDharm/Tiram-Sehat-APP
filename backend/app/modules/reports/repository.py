"""Reports repository — SQL queries for analytics & reports."""
from __future__ import annotations

from typing import Any
from app.core.database import fetch_all, fetch_one


async def get_daily_report(date_str: str, kumbung_id: str | None = None) -> dict[str, Any] | None:
    query = """
    WITH today AS (
      SELECT COALESCE(SUM(weight_kg), 0)::float8 AS total_kg,
             COALESCE(SUM(gross_income), 0)::bigint AS sales,
             COALESCE(AVG(price_per_kg), 0)::int AS price_per_kg
      FROM harvest_entries
      WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
        AND (harvested_at AT TIME ZONE 'Asia/Jakarta')::date = %(date)s::date
    ),
    yesterday AS (
      SELECT COALESCE(SUM(weight_kg), 0)::float8 AS kg
      FROM harvest_entries
      WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
        AND (harvested_at AT TIME ZONE 'Asia/Jakarta')::date = (%(date)s::date - 1)
    )
    SELECT today.total_kg,
           (today.total_kg - yesterday.kg)::float8 AS delta_kg,
           CASE WHEN yesterday.kg = 0 THEN 0.0
                ELSE ROUND(((today.total_kg - yesterday.kg) / yesterday.kg)::numeric * 100, 1)::float8
           END AS delta_pct,
           today.sales,
           today.price_per_kg
    FROM today, yesterday;
    """
    return await fetch_one(query, {"date": date_str, "kumbung_id": kumbung_id})


async def get_trend_report(weeks: int = 4, kumbung_id: str | None = None) -> list[dict[str, Any]]:
    query = """
    SELECT to_char(date_trunc('week', harvested_at), 'YYYY-"W"IW') AS week_label,
           COALESCE(SUM(weight_kg), 0)::float8 AS total_kg
    FROM harvest_entries
    WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
      AND harvested_at >= (now() - interval '%(weeks)s weeks')
    GROUP BY date_trunc('week', harvested_at)
    ORDER BY date_trunc('week', harvested_at) ASC;
    """
    try:
        return await fetch_all(query, {"weeks": weeks, "kumbung_id": kumbung_id})
    except Exception:
        return []


async def get_monthly_report(month_str: str, kumbung_id: str | None = None) -> dict[str, Any] | None:
    query = """
    SELECT COALESCE(SUM(gross_income), 0)::bigint AS income,
           COALESCE(SUM(weight_kg), 0)::float8 AS total_kg
    FROM harvest_entries
    WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
      AND to_char(harvested_at AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM') = %(month)s;
    """
    return await fetch_one(query, {"month": month_str, "kumbung_id": kumbung_id})

