"""Home summary schemas."""
from __future__ import annotations

from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field


class RecentHarvestItem(BaseModel):
    id: str
    harvested_at: str
    weight_kg: float
    gross_income: int


class SelfCheckInfo(BaseModel):
    checked: int = 0
    target: int = 100


class HomeSummaryResponse(BaseModel):
    date: str
    today_kg: float = 0.0
    today_income: int = 0
    delta_pct: float = 0.0
    active_baglogs: int = 0
    healthy_baglogs: int = 0
    contaminated_baglogs: int = 0
    baglog_breakdown: dict[str, int] = Field(default_factory=dict)
    self_check: SelfCheckInfo = Field(default_factory=SelfCheckInfo)
    recent_harvests: list[RecentHarvestItem] = Field(default_factory=list)

