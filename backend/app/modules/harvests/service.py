"""Harvest service."""
from __future__ import annotations

from app.core.database import with_transaction
from app.core.exceptions import AppException
from app.modules.harvests import repository
from app.modules.harvests.schemas import CreateHarvestRequest, UpdateHarvestRequest


async def create_harvest(user_id: str, payload: CreateHarvestRequest) -> dict:
    gross_income = int(round(payload.weight_kg * payload.price_per_kg))
    data = {
        "user_id": user_id,
        "batch_id": payload.batch_id,
        "kumbung_id": payload.kumbung_id,
        "harvested_at": payload.harvested_at,
        "weight_kg": payload.weight_kg,
        "price_per_kg": payload.price_per_kg,
        "gross_income": gross_income,
        "note": payload.note,
    }

    async def _insert(conn):
        return await repository.create_harvest(conn, data)

    res = await with_transaction(_insert)
    if not res:
        raise AppException(500, "DB_ERROR", "Gagal menyimpan data panen")
    return res


async def get_harvest(harvest_id: str, user_id: str | None = None) -> dict:
    res = await repository.get_harvest_by_id(harvest_id, user_id=user_id)
    if not res:
        raise AppException(404, "NOT_FOUND", "Data panen tidak ditemukan")
    return res


async def list_harvests(
    user_id: str | None = None,
    kumbung_id: str | None = None,
    from_date: str | None = None,
    to_date: str | None = None,
    limit: int = 20,
    cursor: str | None = None,
) -> list[dict]:
    return await repository.list_harvests(
        user_id=user_id,
        kumbung_id=kumbung_id,
        from_date=from_date,
        to_date=to_date,
        limit=limit,
        cursor=cursor,
    )


async def update_harvest(
    harvest_id: str,
    payload: UpdateHarvestRequest,
    user_id: str | None = None,
) -> dict:
    existing = await get_harvest(harvest_id, user_id=user_id)
    update_data = {}
    if payload.harvested_at is not None:
        update_data["harvested_at"] = payload.harvested_at
    if payload.note is not None:
        update_data["note"] = payload.note

    weight = payload.weight_kg if payload.weight_kg is not None else existing["weight_kg"]
    price = payload.price_per_kg if payload.price_per_kg is not None else existing["price_per_kg"]
    if payload.weight_kg is not None or payload.price_per_kg is not None:
        update_data["weight_kg"] = weight
        update_data["price_per_kg"] = price
        update_data["gross_income"] = int(round(weight * price))

    async def _up(conn):
        return await repository.update_harvest(
            conn, harvest_id, update_data, user_id=user_id
        )

    res = await with_transaction(_up)
    return res


async def delete_harvest(harvest_id: str, user_id: str | None = None) -> None:
    await get_harvest(harvest_id, user_id=user_id)

    async def _del(conn):
        await repository.delete_harvest(conn, harvest_id, user_id=user_id)

    await with_transaction(_del)

