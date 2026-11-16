"""Home service — business logic for dashboard summary."""
from __future__ import annotations

from datetime import date
from typing import Any
from app.modules.home import repository
from app.modules.home.schemas import HomeSummaryResponse, RecentHarvestItem, SelfCheckInfo


async def get_summary(
    target_date: str | None = None,
    kumbung_id: str | None = None,
    user_id: str | None = None,
) -> HomeSummaryResponse:
    """Compile and return dashboard summary for the given date and kumbung."""
    if not target_date:
        target_date = date.today().isoformat()

    row = await repository.get_home_summary_data(
        date_str=target_date,
        kumbung_id=kumbung_id,
        user_id=user_id,
    )

    if not row:
        # Graceful fallback if database has no rows or is still being seeded
        return HomeSummaryResponse(
            date=target_date,
            today_kg=0.0,
            today_income=0,
            delta_pct=0.0,
            active_baglogs=0,
            healthy_baglogs=0,
            contaminated_baglogs=0,
            baglog_breakdown={
                "sehat": 0,
                "bisa_diobati": 0,
                "sedang_diobati": 0,
                "afkir": 0,
                "dibuang": 0,
                "panen": 0,
            },
            self_check=SelfCheckInfo(checked=0, target=100),
            recent_harvests=[],
        )

    # Parse breakdown dict
    raw_breakdown = row.get("baglog_breakdown") or {}
    if isinstance(raw_breakdown, dict):
        breakdown = {str(k): int(v) for k, v in raw_breakdown.items()}
    else:
        breakdown = {}

    # Parse self check
    sc_data = row.get("self_check") or {}
    self_check = SelfCheckInfo(
        checked=int(sc_data.get("checked", 0)),
        target=int(sc_data.get("target", 100)),
    )

    # Parse recent harvests
    raw_harvests = row.get("recent_harvests") or []
    recent_harvests: list[RecentHarvestItem] = []
    if isinstance(raw_harvests, list):
        for h in raw_harvests:
            if isinstance(h, dict) and "id" in h:
                recent_harvests.append(
                    RecentHarvestItem(
                        id=str(h["id"]),
                        harvested_at=str(h.get("harvested_at", "")),
                        weight_kg=float(h.get("weight_kg", 0.0)),
                        gross_income=int(h.get("gross_income", 0)),
                    )
                )

    return HomeSummaryResponse(
        date=target_date,
        today_kg=float(row.get("today_kg", 0.0) or 0.0),
        today_income=int(row.get("today_income", 0) or 0),
        delta_pct=float(row.get("delta_pct", 0.0) or 0.0),
        active_baglogs=int(row.get("active_baglogs", 0) or 0),
        healthy_baglogs=int(row.get("healthy_baglogs", 0) or 0),
        contaminated_baglogs=int(row.get("contaminated_baglogs", 0) or 0),
        baglog_breakdown=breakdown,
        self_check=self_check,
        recent_harvests=recent_harvests,
    )

