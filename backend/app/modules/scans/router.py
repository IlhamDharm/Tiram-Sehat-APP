"""Scan router — REST API endpoints for scans and actions."""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Query, Response

from app.core.deps import get_current_user_id
from app.core.exceptions import success_response
from app.modules.scans import service
from app.modules.scans.schemas import (
    BatchSyncScanRequest,
    CreateActionRequest,
    CreateScanRequest,
    UpdateScanRequest,
)

router = APIRouter()


@router.post("", status_code=201)
async def create_scan(
    payload: CreateScanRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
):
    """Save an on-device scan result, or trigger server inference if needed."""
    scan = await service.create_scan(
        payload, user_id=user_id, background_tasks=background_tasks
    )
    return success_response(
        {
            "id": str(scan["id"]),
            "inference_status": scan.get("inference_status", "completed"),
        },
        status_code=201,
    )


@router.post("/batch", status_code=201)
async def batch_sync(
    payload: BatchSyncScanRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Sync multiple offline on-device scans after the device reconnects."""
    results = await service.batch_sync_scans(payload.scans, user_id=user_id)
    return success_response(
        {"synced_count": len(results), "items": results},
        status_code=201,
    )


@router.get("/{scan_id}")
async def get_scan(
    scan_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Get one scan owned by the authenticated user."""
    scan = await service.get_scan_detail(scan_id, user_id=user_id)
    return success_response(scan)


@router.get("")
async def list_scans(
    status: Optional[str] = Query(None),
    rak_id: Optional[str] = Query(None),
    disease_id: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    """List scans for the authenticated farmer with filters and pagination."""
    items = await service.list_scans(
        user_id=user_id,
        status=status,
        rak_id=rak_id,
        disease_id=disease_id,
        limit=limit,
        cursor=cursor,
    )
    return success_response(items)


@router.patch("/{scan_id}")
async def update_scan(
    scan_id: str,
    payload: UpdateScanRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Update status, tag, or note of a scan owned by the user."""
    updated = await service.update_scan(scan_id, payload, user_id=user_id)
    return success_response(updated)


@router.post("/{scan_id}/actions", status_code=201)
async def add_action(
    scan_id: str,
    payload: CreateActionRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Log a treatment or status change action for this scan."""
    action = await service.add_action_log(scan_id, user_id, payload)
    return success_response(action, status_code=201)


@router.delete("/{scan_id}", status_code=204)
async def delete_scan(
    scan_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Delete a scan owned by the authenticated user."""
    await service.delete_scan(scan_id, user_id=user_id)
    return Response(status_code=204)
