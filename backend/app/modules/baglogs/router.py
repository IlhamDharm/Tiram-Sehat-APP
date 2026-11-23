"""Baglogs router."""
from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Query

from app.core.exceptions import success_response
from app.modules.baglogs import service
from app.modules.baglogs.schemas import CreateBaglogRequest, UpdateBaglogStatusRequest

router = APIRouter()


@router.post("", status_code=201)
async def create_baglog(payload: CreateBaglogRequest):
    """Register a new baglog on a rack column."""
    result = await service.create_baglog(payload)
    return success_response(result, status_code=201)


@router.get("/{baglog_id}")
async def get_baglog(baglog_id: str):
    """Get baglog details."""
    result = await service.get_baglog(baglog_id)
    return success_response(result)


@router.get("")
async def list_baglogs_by_rak(rak_id: str = Query(..., description="Rack UUID")):
    """List all baglogs located in a specific rack."""
    items = await service.list_by_rak(rak_id)
    return success_response(items)


@router.patch("/{baglog_id}/status")
async def update_baglog_status(baglog_id: str, payload: UpdateBaglogStatusRequest):
    """Update baglog health status (e.g. sehat, bisa_diobati, afkir)."""
    updated = await service.update_status(baglog_id, payload.status)
    return success_response(updated)

