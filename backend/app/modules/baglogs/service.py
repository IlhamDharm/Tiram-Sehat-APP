"""Baglog service."""
from __future__ import annotations

from app.core.database import with_transaction
from app.core.exceptions import AppException
from app.modules.baglogs import repository
from app.modules.baglogs.schemas import CreateBaglogRequest, UpdateBaglogStatusRequest


async def create_baglog(payload: CreateBaglogRequest) -> dict:
    code = payload.code or f"BG-{payload.rak_id[:4]}-{payload.column_no:02d}"
    data = {
        "code": code,
        "batch_id": payload.batch_id,
        "rak_id": payload.rak_id,
        "column_no": payload.column_no,
        "status": payload.status,
    }

    async def _create(conn):
        return await repository.create_baglog(conn, data)

    res = await with_transaction(_create)
    return res


async def get_baglog(baglog_id: str) -> dict:
    res = await repository.get_baglog_by_id(baglog_id)
    if not res:
        raise AppException(404, "NOT_FOUND", "Baglog tidak ditemukan")
    return res


async def list_by_rak(rak_id: str) -> list[dict]:
    return await repository.list_baglogs_by_rak(rak_id)


async def update_status(baglog_id: str, status: str) -> dict:
    await get_baglog(baglog_id)

    async def _update(conn):
        return await repository.update_baglog_status(conn, baglog_id, status)

    return await with_transaction(_update)

