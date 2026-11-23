"""Report router."""
from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends, Query

from app.core.deps import get_current_user_id
from app.core.exceptions import success_response
from app.modules.reports import service
from app.modules.reports.schemas import CreateExportRequest

router = APIRouter()


@router.get("/daily")
async def get_daily_report(
    date: Optional[str] = Query(None, description="Date in YYYY-MM-DD"),
    kumbung_id: Optional[str] = Query(None),
):
    """Get daily harvest and sales report."""
    report = await service.get_daily_report(target_date=date, kumbung_id=kumbung_id)
    return success_response(report.model_dump())


@router.get("/trend")
async def get_trend_report(
    weeks: int = Query(4, ge=1, le=52),
    kumbung_id: Optional[str] = Query(None),
):
    """Get weekly production trend."""
    report = await service.get_trend_report(weeks=weeks, kumbung_id=kumbung_id)
    return success_response(report.model_dump())


@router.get("/monthly")
async def get_monthly_report(
    month: Optional[str] = Query(None, description="Month in YYYY-MM"),
    kumbung_id: Optional[str] = Query(None),
):
    """Get monthly harvest overview and loss reduction."""
    report = await service.get_monthly_report(month_str=month, kumbung_id=kumbung_id)
    return success_response(report.model_dump())


@router.post("/exports")
async def export_report(
    payload: CreateExportRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Generate and return export download URL."""
    result = await service.export_report(user_id=user_id, payload=payload)
    return success_response(result)

