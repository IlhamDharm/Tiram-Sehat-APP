"""Home router — dashboard summary endpoints."""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.deps import get_optional_user_id
from app.core.exceptions import success_response
from app.modules.home import service

router = APIRouter()


@router.get("/summary")
async def get_home_summary(
    date: Optional[str] = Query(None, description="Date in YYYY-MM-DD format"),
    kumbung_id: Optional[str] = Query(None, description="Optional filter by kumbung UUID"),
    user_id: Optional[str] = Depends(get_optional_user_id),
):
    """Get aggregated home/beranda dashboard data.

    Endpoint ini boleh diakses tanpa token, tetapi token yang dikirim harus
    valid. Dengan token, preferensi/self-check difilter per pengguna.
    """
    summary = await service.get_summary(
        target_date=date,
        kumbung_id=kumbung_id,
        user_id=user_id,
    )
    return success_response(summary.model_dump())
