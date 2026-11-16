"""Scan service — coordinates scan lifecycle, async ML inference, and DB transactions."""
from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import BackgroundTasks

from app.core.cloudinary import build_image_url, build_thumbnail_url
from app.core.config import settings
from app.core.database import with_transaction
from app.core.exceptions import AppException
from app.core.ml_client import predict_from_url
from app.modules.diseases import repository as diseases_repo
from app.modules.scans import repository as scans_repo
from app.modules.scans import steps_repository as scan_steps_repo
from app.modules.scans.schemas import CreateActionRequest, CreateScanRequest, UpdateScanRequest

logger = logging.getLogger(__name__)


async def _resolve_rak_id(conn, raw_id: str) -> str:
    """Resolve raw rak identifier (either UUID or code like 'B-04') to a valid UUID."""
    try:
        uuid.UUID(str(raw_id))
        return str(raw_id)
    except (ValueError, AttributeError):
        pass

    # Lookup by code (e.g. 'B-04')
    cur = await conn.execute(
        "SELECT id FROM raks WHERE code = %(code)s LIMIT 1",
        {"code": str(raw_id).strip()},
    )
    row = await cur.fetchone()
    if row:
        return str(row["id"])

    # Fallback to first available rak in database
    cur = await conn.execute("SELECT id FROM raks ORDER BY code LIMIT 1")
    row = await cur.fetchone()
    if row:
        return str(row["id"])

    return "b0000000-0000-0000-0000-000000000002"


async def create_scan(payload: CreateScanRequest, user_id: str, background_tasks: BackgroundTasks | None = None) -> dict:
    """Create a scan record. If on-device inference is already completed, save directly as completed."""
    thumbnail_url = payload.image_thumbnail_url
    if not thumbnail_url and payload.image_public_id:
        thumbnail_url = build_thumbnail_url(payload.image_public_id)

    # 1. Cek apakah inferensi sudah dilakukan on-device oleh Flutter
    on_device_completed = bool(payload.diagnosis_name or payload.ml_label)

    disease = None
    if payload.ml_label:
        disease = await diseases_repo.find_by_ml_label(payload.ml_label)
    elif payload.diagnosis_name:
        active_diseases = await diseases_repo.list_all_active()
        for d in active_diseases:
            if d["name"].lower() == payload.diagnosis_name.lower():
                disease = d
                break

    disease_id = str(disease["id"]) if disease else payload.disease_id
    diagnosis_name = disease["name"] if disease else (payload.diagnosis_name or "Pending")
    scientific_name = disease.get("scientific_name") if disease else payload.scientific_name
    location_hint = disease.get("location_hint") if disease else payload.infection_location

    is_healthy = bool(disease and disease.get("is_healthy")) or payload.severity == "healthy"
    severity = "healthy" if is_healthy else (payload.severity or (disease.get("default_severity") if disease else "treatable"))
    status = "archived" if is_healthy else "action_required"

    inference_status = "completed" if on_device_completed else "pending"

    insert_data = {
        "user_id": user_id,
        "rak_id": payload.rak_id,
        "column_no": payload.column_no,
        "batch_id": payload.batch_id,
        "disease_id": disease_id,
        "diagnosis_name": diagnosis_name,
        "scientific_name": scientific_name,
        "confidence": payload.confidence,
        "infection_location": location_hint,
        "severity": severity,
        "scan_method": payload.scan_method or "on_device_tflite",
        "image_public_id": payload.image_public_id,
        "image_url": payload.image_url,
        "image_version": payload.image_version,
        "image_thumbnail_url": thumbnail_url,
        "status": status,
        "scanned_at": payload.scanned_at or datetime.now(timezone.utc).isoformat(),
        "inference_status": inference_status,
    }

    async def _insert(conn):
        resolved_rak_id = await _resolve_rak_id(conn, payload.rak_id)
        insert_data["rak_id"] = resolved_rak_id
        created = await scans_repo.create_scan(conn, insert_data)
        # Jika ada disease dan inferensi sudah selesai, salin langkah SOP
        if created and disease_id and not is_healthy:
            await scan_steps_repo.copy_disease_steps_to_scan(conn, str(created["id"]), disease_id)
        return created

    scan = await with_transaction(_insert)
    if not scan:
        raise AppException(500, "DATABASE_ERROR", "Gagal menyimpan data scan")

    # Jika belum ada diagnosa on-device dan ada image, fallback jalankan server-side ML
    if not on_device_completed and (payload.image_public_id or payload.image_url):
        if background_tasks:
            background_tasks.add_task(run_inference, str(scan["id"]))

    return scan


async def batch_sync_scans(scans: list[CreateScanRequest], user_id: str) -> list[dict]:
    """Sync multiple offline on-device scans from Flutter in one request."""
    synced = []
    for item in scans:
        try:
            res = await create_scan(item, user_id=user_id, background_tasks=None)
            synced.append(res)
        except Exception as e:
            logger.warning("Failed to sync item %s: %s", item.client_id, e)
    return synced


async def run_inference(scan_id: str) -> None:
    """Background task: call ML service and record predictions + treatment steps."""
    scan = await scans_repo.get_scan_by_id(scan_id)
    if not scan:
        logger.error("Scan %s not found for inference", scan_id)
        return

    # Image URL to pass to ML
    if scan.get("image_public_id"):
        ml_image_url = build_image_url(scan["image_public_id"], width=1024, fmt="jpg")
    else:
        ml_image_url = scan.get("image_url")

    if not ml_image_url:
        await scans_repo.mark_failed(scan_id, "No valid image URL for inference")
        return

    for attempt in range(1, settings.HF_MAX_RETRIES + 1):
        await scans_repo.mark_processing(scan_id, attempt)
        try:
            logger.info("Running inference for scan %s (attempt %s)", scan_id, attempt)
            prediction = await predict_from_url(ml_image_url)
            disease = await diseases_repo.find_by_ml_label(prediction.label)

            is_healthy = bool(disease and disease.get("is_healthy"))
            severity = "healthy" if is_healthy else (disease.get("default_severity", "treatable") if disease else "treatable")
            scan_status = "archived" if is_healthy else "action_required"

            complete_data = {
                "ml_label": prediction.label,
                "disease_id": str(disease["id"]) if disease else None,
                "diagnosis_name": disease["name"] if disease else prediction.label,
                "scientific_name": disease.get("scientific_name") if disease else None,
                "infection_location": disease.get("location_hint") if disease else None,
                "severity": severity,
                "confidence": prediction.confidence,
                "model_version": prediction.model_version,
                "raw_response": json.dumps(prediction.model_dump()),
                "status": scan_status,
            }

            async def _persist(conn):
                updated = await scans_repo.complete_inference(conn, scan_id, complete_data)
                if disease and not is_healthy:
                    await scan_steps_repo.copy_disease_steps_to_scan(conn, scan_id, str(disease["id"]))
                return updated

            await with_transaction(_persist)
            logger.info("Inference completed successfully for scan %s (label=%s)", scan_id, prediction.label)
            return

        except Exception as exc:
            logger.warning("Inference attempt %s failed for scan %s: %s", attempt, scan_id, exc)
            await scans_repo.mark_failed(scan_id, str(exc))
            if attempt < settings.HF_MAX_RETRIES:
                await asyncio.sleep(2 * attempt)


async def get_scan_detail(scan_id: str, user_id: str | None = None) -> dict:
    """Get scan row along with its scan_steps."""
    scan = await scans_repo.get_scan_by_id(scan_id, user_id=user_id)
    if not scan:
        raise AppException(404, "NOT_FOUND", "Scan tidak ditemukan")

    steps = await scan_steps_repo.get_steps_for_scan(scan_id)
    scan["steps"] = steps
    return scan


async def list_scans(
    user_id: str,
    status: str | None = None,
    rak_id: str | None = None,
    disease_id: str | None = None,
    limit: int = 20,
    cursor: str | None = None,
) -> list[dict]:
    return await scans_repo.list_scans(
        user_id=user_id,
        status=status,
        rak_id=rak_id,
        disease_id=disease_id,
        limit=limit,
        cursor=cursor,
    )


async def update_scan(
    scan_id: str, payload: UpdateScanRequest, user_id: str | None = None
) -> dict:
    scan = await scans_repo.get_scan_by_id(scan_id, user_id=user_id)
    if not scan:
        raise AppException(404, "NOT_FOUND", "Scan tidak ditemukan")

    async def _update(conn):
        return await scans_repo.update_scan_status(
            conn,
            scan_id=scan_id,
            status=payload.status or scan["status"],
            note=payload.status_note,
            tag=payload.status_tag,
            user_id=user_id,
        )

    updated = await with_transaction(_update)
    return updated


async def add_action_log(scan_id: str, user_id: str, payload: CreateActionRequest) -> dict:
    scan = await scans_repo.get_scan_by_id(scan_id, user_id=user_id)
    if not scan:
        raise AppException(404, "NOT_FOUND", "Scan tidak ditemukan")

    from_status = scan.get("status")
    to_status = payload.to_status or from_status

    log_data = {
        "scan_id": scan_id,
        "action_type": payload.action_type,
        "from_status": from_status,
        "to_status": to_status,
        "note": payload.note,
        "tag": payload.tag,
        "performed_by": user_id,
        "performed_at": datetime.now(timezone.utc).isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    async def _act(conn):
        log_entry = await scans_repo.create_treatment_log(conn, log_data)
        if to_status and to_status != from_status:
            await scans_repo.update_scan_status(
                conn, scan_id, to_status, payload.note, payload.tag, user_id
            )
        return log_entry

    return await with_transaction(_act)


async def delete_scan(scan_id: str, user_id: str | None = None) -> None:
    scan = await scans_repo.get_scan_by_id(scan_id, user_id=user_id)
    if not scan:
        raise AppException(404, "NOT_FOUND", "Scan tidak ditemukan")

    async def _del(conn):
        await scans_repo.delete_scan(conn, scan_id, user_id=user_id)

    await with_transaction(_del)

