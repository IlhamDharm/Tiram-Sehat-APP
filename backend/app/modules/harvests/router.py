"""Harvest router."""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query, Response

from app.core.deps import get_current_user_id
from app.core.exceptions import success_response
from app.modules.harvests import service
from app.modules.harvests.schemas import CreateHarvestRequest, UpdateHarvestRequest

router = APIRouter()


@router.post("", status_code=201)
async def create_harvest(
    payload: CreateHarvestRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Record a new mushroom harvest entry."""
    result = await service.create_harvest(user_id, payload)
    return success_response(result, status_code=201)


@router.get("")
async def list_harvests(
    kumbung_id: Optional[str] = Query(None),
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    limit: int = Query(20, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    """List harvest entries with date filters and pagination."""
    items = await service.list_harvests(
        user_id=user_id,
        kumbung_id=kumbung_id,
        from_date=from_date,
        to_date=to_date,
        limit=limit,
        cursor=cursor,
    )
    return success_response(items)


@router.get("/{harvest_id}")
async def get_harvest(
    harvest_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Get single harvest details owned by the authenticated user."""
    item = await service.get_harvest(harvest_id, user_id=user_id)
    return success_response(item)


@router.patch("/{harvest_id}")
async def update_harvest(
    harvest_id: str,
    payload: UpdateHarvestRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Update harvest entry owned by the authenticated user."""
    updated = await service.update_harvest(harvest_id, payload, user_id=user_id)
    return success_response(updated)


@router.delete("/{harvest_id}", status_code=204)
async def delete_harvest(
    harvest_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Delete harvest entry owned by the authenticated user."""
    await service.delete_harvest(harvest_id, user_id=user_id)
    return Response(status_code=204)
