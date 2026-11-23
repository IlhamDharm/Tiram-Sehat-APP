"""Report service."""
from __future__ import annotations

from datetime import date
from app.modules.reports import repository
from app.modules.reports.schemas import (
    BatchInfo,
    CreateExportRequest,
    DailyReportOut,
    MonthlyReportOut,
    TrendPoint,
    TrendReportOut,
)


async def get_daily_report(target_date: str | None = None, kumbung_id: str | None = None) -> DailyReportOut:
    if not target_date:
        target_date = date.today().isoformat()
    row = await repository.get_daily_report(target_date, kumbung_id)
    if not row:
        return DailyReportOut(
            date=target_date,
            total_kg=0.0,
            delta_kg=0.0,
            delta_pct=0.0,
            sales=0,
            price_per_kg=0,
        )
    return DailyReportOut(
        date=target_date,
        total_kg=float(row.get("total_kg", 0.0) or 0.0),
        delta_kg=float(row.get("delta_kg", 0.0) or 0.0),
        delta_pct=float(row.get("delta_pct", 0.0) or 0.0),
        sales=int(row.get("sales", 0) or 0),
        price_per_kg=int(row.get("price_per_kg", 0) or 0),
    )


async def get_trend_report(weeks: int = 4, kumbung_id: str | None = None) -> TrendReportOut:
    rows = await repository.get_trend_report(weeks, kumbung_id)
    points = [TrendPoint(label=f"M{i+1}", value=float(r.get("total_kg", 0.0))) for i, r in enumerate(rows)]
    delta = 0.0
    if len(points) >= 2:
        delta = round(points[-1].value - points[0].value, 1)
    return TrendReportOut(points=points, delta=delta)


async def get_monthly_report(month_str: str | None = None, kumbung_id: str | None = None) -> MonthlyReportOut:
    if not month_str:
        month_str = date.today().strftime("%Y-%m")
    row = await repository.get_monthly_report(month_str, kumbung_id)
    income = int(row.get("income", 0) or 0) if row else 0
    total_kg = float(row.get("total_kg", 0.0) or 0.0) if row else 0.0

    return MonthlyReportOut(
        month=month_str,
        income=income,
        total_kg=total_kg,
        estimated_loss=420000,
        loss_reduced_pct=65,
        batch=BatchInfo(
            code="Batch Panen K-04 Margomulyo",
            variety="Florida Putih",
            day=42,
            grade="98% Grade A",
            weighed_at="07:30 WIB",
        ),
    )


async def export_report(user_id: str, payload: CreateExportRequest) -> dict:
    return {
        "download_url": f"https://api.tiramsehat.id/downloads/report-{payload.period_type}-{payload.period_start}.csv",
        "format": payload.format,
        "expires_in": 3600,
    }

