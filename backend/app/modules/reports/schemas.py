"""Report schemas."""
from __future__ import annotations

from pydantic import BaseModel


class DailyReportOut(BaseModel):
    date: str
    total_kg: float
    delta_kg: float
    delta_pct: float
    sales: int
    price_per_kg: int


class TrendPoint(BaseModel):
    label: str
    value: float


class TrendReportOut(BaseModel):
    points: list[TrendPoint] = []
    delta: float = 0.0


class BatchInfo(BaseModel):
    code: str
    variety: str
    day: int
    grade: str
    weighed_at: str


class MonthlyReportOut(BaseModel):
    month: str
    income: int
    total_kg: float
    estimated_loss: int
    loss_reduced_pct: int
    batch: BatchInfo | None = None


class CreateExportRequest(BaseModel):
    period_type: str = "month"
    period_start: str
    period_end: str
    format: str = "csv"

