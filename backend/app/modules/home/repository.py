"""Home repository — aggregated SQL query for dashboard summary."""
from __future__ import annotations

import logging
from typing import Any
from app.core.database import fetch_one

logger = logging.getLogger(__name__)


async def get_home_summary_data(
    date_str: str,
    kumbung_id: str | None = None,
    user_id: str | None = None,
) -> dict[str, Any] | None:
    """Fetch aggregated dashboard summary data in a single SQL query."""
    query = """
    WITH today AS (
      SELECT COALESCE(SUM(weight_kg), 0)::float8 AS today_kg,
             COALESCE(SUM(gross_income), 0)::bigint AS today_income
      FROM harvest_entries
      WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
        AND (harvested_at AT TIME ZONE 'Asia/Jakarta')::date = %(date)s::date
    ),
    yesterday AS (
      SELECT COALESCE(SUM(weight_kg), 0)::float8 AS kg
      FROM harvest_entries
      WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
        AND (harvested_at AT TIME ZONE 'Asia/Jakarta')::date = (%(date)s::date - 1)
    ),
    baglog_stats AS (
      SELECT COALESCE(SUM(cnt), 0)::int AS active_baglogs,
             COALESCE(SUM(cnt) FILTER (WHERE status = 'sehat'), 0)::int AS healthy_baglogs,
             COALESCE(SUM(cnt) FILTER (WHERE status IN ('bisa_diobati', 'sedang_diobati', 'afkir')), 0)::int AS contaminated_baglogs,
             COALESCE(jsonb_object_agg(status, cnt), '{}'::jsonb) AS baglog_breakdown
      FROM (
        SELECT b.status, COUNT(*) AS cnt
        FROM baglogs b
        JOIN raks r ON r.id = b.rak_id
        WHERE (%(kumbung_id)s::uuid IS NULL OR r.kumbung_id = %(kumbung_id)s::uuid)
          AND b.status NOT IN ('dibuang', 'panen')
        GROUP BY b.status
      ) s
    ),
    self_check_row AS (
      SELECT COALESCE(di.checked_count, 0) AS checked,
             COALESCE(di.target, up.daily_check_target, 100) AS target
      FROM user_preferences up
      LEFT JOIN daily_inspections di
        ON (%(kumbung_id)s::uuid IS NULL OR di.kumbung_id = %(kumbung_id)s::uuid)
       AND di.date = %(date)s::date
      WHERE %(user_id)s::uuid IS NULL OR up.user_id = %(user_id)s::uuid
      LIMIT 1
    ),
    recent AS (
      SELECT id::text,
             to_char(harvested_at, 'YYYY-MM-DD"T"HH24:MI:SSOF') AS harvested_at,
             weight_kg::float8 AS weight_kg,
             gross_income
      FROM harvest_entries
      WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
      ORDER BY harvested_at DESC
      LIMIT 5
    )
    SELECT today.today_kg,
           today.today_income,
           CASE WHEN yesterday.kg = 0 THEN 0.0
                ELSE ROUND(((today.today_kg - yesterday.kg) / yesterday.kg)::numeric * 100, 1)::float8
           END AS delta_pct,
           baglog_stats.active_baglogs,
           baglog_stats.healthy_baglogs,
           baglog_stats.contaminated_baglogs,
           baglog_stats.baglog_breakdown,
           jsonb_build_object(
             'checked', COALESCE((SELECT checked FROM self_check_row), 0),
             'target',  COALESCE((SELECT target  FROM self_check_row), 100)
           ) AS self_check,
           (SELECT COALESCE(json_agg(r), '[]'::json) FROM recent r) AS recent_harvests
    FROM today, yesterday, baglog_stats;
    """

    params = {
        "date": date_str,
        "kumbung_id": kumbung_id,
        "user_id": user_id,
    }

    try:
        return await fetch_one(query, params)
    except Exception:
        logger.exception("Failed to fetch home summary via SQL query")
        raise

