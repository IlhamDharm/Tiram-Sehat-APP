"""Harvest service."""
from __future__ import annotations

from app.core.database import fetch_one, with_transaction
from app.core.exceptions import AppException
from app.modules.harvests import repository
from app.modules.harvests.schemas import CreateHarvestRequest, UpdateHarvestRequest


async def create_harvest(user_id: str, payload: CreateHarvestRequest) -> dict:
    gross_income = int(round(payload.weight_kg * payload.price_per_kg))

    kumbung_id = payload.kumbung_id
    batch_id = payload.batch_id

    # Fallback otomatis ke active kumbung & active batch jika tidak dikirim dari form
    if not kumbung_id:
        pref = await fetch_one(
            "SELECT active_kumbung_id FROM user_preferences WHERE user_id = %(user_id)s",
            {"user_id": user_id},
        )
        if pref and pref.get("active_kumbung_id"):
            kumbung_id = str(pref["active_kumbung_id"])
        else:
            kumbung = await fetch_one("SELECT id FROM kumbungs LIMIT 1")
            if kumbung:
                kumbung_id = str(kumbung["id"])

    if not batch_id:
        batch = await fetch_one(
            """
            SELECT id FROM baglog_batches
            WHERE (%(kumbung_id)s::uuid IS NULL OR kumbung_id = %(kumbung_id)s::uuid)
              AND status = 'active'
            ORDER BY planted_at DESC
            LIMIT 1
            """,
            {"kumbung_id": kumbung_id},
        )
        if batch:
            batch_id = str(batch["id"])
        else:
            batch = await fetch_one("SELECT id FROM baglog_batches LIMIT 1")
            if batch:
                batch_id = str(batch["id"])

    data = {
        "user_id": user_id,
        "batch_id": batch_id,
        "kumbung_id": kumbung_id,
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

