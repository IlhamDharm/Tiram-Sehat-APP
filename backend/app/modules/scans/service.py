"""Scan service — coordinates scan lifecycle, async ML inference, and DB transactions."""
from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import BackgroundTasks
from PIL import UnidentifiedImageError

from app.core.cloudinary import build_image_url, build_thumbnail_url
from app.core.config import settings
from app.core.database import with_transaction
from app.core.exceptions import AppException
from app.core.ml_client import predict_from_url
from app.core.tflite_model import predict_image_bytes_async
from app.modules.diseases import repository as diseases_repo
from app.modules.scans import repository as scans_repo
from app.modules.scans import steps_repository as scan_steps_repo
from app.modules.scans.schemas import CreateActionRequest, CreateScanRequest, UpdateScanRequest

logger = logging.getLogger(__name__)

_MAX_PREDICT_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB
_ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}
_ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}

_FALLBACK_DISEASE_METADATA: dict[str, dict[str, Any]] = {
    "healthy": {
        "name": "Baglog Sehat Produktif",
        "scientific_name": "Pleurotus ostreatus",
        "severity": "healthy",
        "is_healthy": True,
        "location_hint": "Seluruh Baglog",
        "description": (
            "Baglog dalam kondisi optimal, miselium putih merambat tebal "
            "tanpa tanda kontaminasi green mold maupun black mold."
        ),
        "steps": [
            {
                "step_order": 1,
                "title": "Jaga Kelembapan Optimal",
                "description": (
                    "Pertahankan kelembapan relatif 80-90% dengan penyemprotan "
                    "kabut halus 2-3 kali sehari."
                ),
            },
            {
                "step_order": 2,
                "title": "Pastikan Sirkulasi Udara Lancar",
                "description": (
                    "Buka ventilasi kumbung secara berkala agar sirkulasi oksigen "
                    "optimal untuk pembentukan pinhead."
                ),
            },
        ],
    },
    "greenmold": {
        "name": "Green Mold",
        "scientific_name": "Trichoderma sp.",
        "severity": "treatable",
        "is_healthy": False,
        "location_hint": "Cincin & Leher Baglog",
        "description": (
            "Kontaminasi jamur hijau (Trichoderma sp.) pada permukaan atau "
            "leher baglog. Masih dapat ditangani melalui karantina dan tindakan kuratif."
        ),
        "steps": [
            {
                "step_order": 1,
                "title": "Pindahkan ke Rak Karantina",
                "description": (
                    "Segera pisahkan baglog dari rak utama kumbung untuk mencegah "
                    "penularan spora via sirkulasi udara lembap."
                ),
            },
            {
                "step_order": 2,
                "title": "Kerik Lembut Spora Hijau",
                "description": (
                    "Gunakan sendok makan bersih yang telah disterilkan alkohol 70%. "
                    "Kerik hingga batas miselium putih yang masih segar."
                ),
            },
            {
                "step_order": 3,
                "title": "Oles Larutan Kapur Tohor (CaCO3)",
                "description": (
                    "Oleskan pasta kapur tohor pekat atau fungisida nabati rebusan "
                    "daun sirih ke bekas kerokan untuk menaikkan pH lokal."
                ),
            },
            {
                "step_order": 4,
                "title": "Observasi Pemulihan 48 Jam",
                "description": (
                    "Jika miselium putih tumbuh menutupi bekas luka, baglog aman. "
                    "Jika spora meluas, segera buang dari kumbung."
                ),
            },
        ],
    },
    "blackmold": {
        "name": "Black Mold",
        "scientific_name": "Rhizopus sp. / Aspergillus niger",
        "severity": "must_discard",
        "is_healthy": False,
        "location_hint": "Permukaan & Substrat Baglog",
        "description": (
            "Kontaminasi jamur hitam (Black Mold) dengan spora agresif yang cepat "
            "menyebar melalui udara. Wajib segera dibuang agar tidak menulari seisi kumbung."
        ),
        "steps": [
            {
                "step_order": 1,
                "title": "Isolasi Segera dengan Plastik",
                "description": (
                    "Tutup baglog rapat dengan plastik sebelum dipindahkan agar spora "
                    "hitam tidak berterbangan di dalam kumbung."
                ),
            },
            {
                "step_order": 2,
                "title": "Musnahkan Jauh dari Kumbung",
                "description": (
                    "Segera buang atau bakar jauh dari area budidaya kumbung. "
                    "Jangan biarkan menumpuk di sekitar kumbung."
                ),
            },
            {
                "step_order": 3,
                "title": "Sterilisasi Lokasi Rak",
                "description": (
                    "Semprot rak bekas baglog dengan alkohol 70% atau disinfektan "
                    "untuk mematikan sisa spora patogen."
                ),
            },
        ],
    },
}

_FALLBACK_LABEL_ALIASES: dict[str, str] = {
    "healthy": "healthy",
    "greenmold": "greenmold",
    "green_mold": "greenmold",
    "blackmold": "blackmold",
    "black_mold": "blackmold",
    "black_bread_mold": "blackmold",
}


def _clean_rak_code(raw_id: str) -> str:
    cleaned = str(raw_id or "").strip()
    for prefix in ("Rak Kumbung ", "rak kumbung ", "Rak-", "rak-", "Rak ", "rak "):
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix) :].strip()
            break
    return cleaned.upper() or "A-01"


async def _get_or_create_kumbung_id(conn, user_id: str | None) -> str:
    if user_id:
        cur = await conn.execute(
            """
            SELECT kumbung_id FROM user_kumbung_assignments
            WHERE user_id = %(uid)s::uuid
            ORDER BY is_primary DESC, assigned_at ASC
            LIMIT 1
            """,
            {"uid": user_id},
        )
        row = await cur.fetchone()
        if row:
            return str(row["kumbung_id"])

    cur = await conn.execute(
        "SELECT id FROM kumbungs WHERE is_active = TRUE ORDER BY code ASC LIMIT 1"
    )
    row = await cur.fetchone()
    if row:
        return str(row["id"])

    cur = await conn.execute(
        """
        INSERT INTO kumbungs (code, name, is_active)
        VALUES ('A', 'Kumbung Blok A', TRUE)
        ON CONFLICT (code) DO UPDATE SET is_active = TRUE
        RETURNING id
        """
    )
    row = await cur.fetchone()
    assert row is not None
    return str(row["id"])


async def _resolve_rak(conn, raw_id: str, user_id: str | None = None) -> tuple[str, str]:
    """Resolve raw rak identifier (UUID or code like 'B-04' / 'Rak Kumbung A') to a valid (rak_id, rak_code) in DB."""
    try:
        uuid.UUID(str(raw_id))
        cur = await conn.execute(
            "SELECT id, code FROM raks WHERE id = %(id)s::uuid LIMIT 1",
            {"id": str(raw_id)},
        )
        row = await cur.fetchone()
        if row:
            return str(row["id"]), str(row["code"])
    except (ValueError, AttributeError):
        pass

    code = _clean_rak_code(raw_id)

    # Lookup exact code (e.g. 'B-04' or 'A'), or block letter (e.g. 'B')
    cur = await conn.execute(
        """
        SELECT id, code FROM raks
        WHERE UPPER(code) = UPPER(%(code)s)
           OR (LENGTH(%(code)s) = 1 AND UPPER(block) = UPPER(%(code)s))
        ORDER BY code ASC
        LIMIT 1
        """,
        {"code": code},
    )
    row = await cur.fetchone()
    if row:
        return str(row["id"]), str(row["code"])

    # Auto-create missing rak under user's / active kumbung so FK never fails
    kumbung_id = await _get_or_create_kumbung_id(conn, user_id)
    block = code[0] if code and code[0].isalpha() else "A"
    cur = await conn.execute(
        """
        INSERT INTO raks (kumbung_id, code, block, column_count, is_active)
        VALUES (%(kid)s::uuid, %(code)s, %(block)s, 8, TRUE)
        ON CONFLICT (kumbung_id, code) DO UPDATE SET is_active = TRUE
        RETURNING id, code
        """,
        {"kid": kumbung_id, "code": code, "block": block},
    )
    row = await cur.fetchone()
    assert row is not None
    return str(row["id"]), str(row["code"])


def _normalize_scan_method(method: str | None) -> str:
    if (method or "").strip().lower() == "manual":
        return "manual"
    return "camera"


def _normalize_confidence(value: float | None) -> float | None:
    if value is None:
        return None
    normalized = value / 100.0 if value > 1.0 else value
    return max(0.0, min(1.0, normalized))


async def create_scan(payload: CreateScanRequest, user_id: str, background_tasks: BackgroundTasks | None = None) -> dict:
    """Create a scan record. If on-device/manual result is provided, save directly as completed."""
    thumbnail_url = payload.image_thumbnail_url
    if not thumbnail_url and payload.image_public_id:
        thumbnail_url = build_thumbnail_url(payload.image_public_id)

    # 1. Cek apakah inferensi sudah dilakukan on-device / input manual
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
    scientific_name = (
        payload.scientific_name
        if payload.scientific_name
        else (disease.get("scientific_name") if disease else None)
    )
    location_hint = (
        payload.infection_location
        if payload.infection_location
        else (disease.get("location_hint") if disease else None)
    )

    is_healthy = bool(disease and disease.get("is_healthy")) or payload.severity == "healthy"
    severity = "healthy" if is_healthy else (payload.severity or (disease.get("default_severity") if disease else "treatable"))
    status = payload.status or ("archived" if is_healthy else "action_required")

    inference_status = "completed" if on_device_completed else "pending"
    scan_method = _normalize_scan_method(payload.scan_method)
    confidence = _normalize_confidence(payload.confidence)

    insert_data = {
        "user_id": user_id,
        "rak_id": payload.rak_id,
        "column_no": payload.column_no,
        "batch_id": payload.batch_id,
        "disease_id": disease_id,
        "diagnosis_name": diagnosis_name,
        "scientific_name": scientific_name,
        "confidence": confidence,
        "infection_location": location_hint,
        "severity": severity,
        "scan_method": scan_method,
        "image_public_id": payload.image_public_id,
        "image_url": payload.image_url,
        "image_version": payload.image_version,
        "image_thumbnail_url": thumbnail_url,
        "status": status,
        "status_note": payload.status_note,
        "status_tag": payload.status_tag,
        "scanned_at": payload.scanned_at or datetime.now(timezone.utc).isoformat(),
        "inference_status": inference_status,
        "ml_label": payload.ml_label or (disease.get("ml_label") if disease else None),
        "model_version": payload.model_version,
    }

    resolved_rak_code = payload.rak_id

    async def _insert(conn):
        nonlocal resolved_rak_code
        resolved_rak_id, resolved_rak_code = await _resolve_rak(
            conn, payload.rak_id, user_id=user_id
        )
        insert_data["rak_id"] = resolved_rak_id
        created = await scans_repo.create_scan(conn, insert_data)
        if created:
            scan_id = str(created["id"])
            if disease_id and not is_healthy:
                await scan_steps_repo.copy_disease_steps_to_scan(conn, scan_id, disease_id)
            elif payload.steps:
                await scan_steps_repo.insert_custom_steps(
                    conn,
                    scan_id,
                    [s.model_dump() for s in payload.steps],
                )
        return created

    scan = await with_transaction(_insert)
    if not scan:
        raise AppException(500, "DATABASE_ERROR", "Gagal menyimpan data scan")

    scan["rak_code"] = resolved_rak_code
    scan["steps"] = await scan_steps_repo.get_steps_for_scan(str(scan["id"]))

    # Jika belum ada diagnosa on-device dan ada image, fallback jalankan server-side ML
    if not on_device_completed and (payload.image_public_id or payload.image_url):
        if background_tasks:
            background_tasks.add_task(run_inference, str(scan["id"]))

    return scan


def _validate_image_upload(contents: bytes, filename: str, content_type: str) -> None:
    if not contents:
        raise AppException(400, "VALIDATION_ERROR", "File gambar kosong")
    if len(contents) > _MAX_PREDICT_IMAGE_BYTES:
        raise AppException(400, "VALIDATION_ERROR", "Ukuran gambar maksimal 10 MB")

    ct = (content_type or "").split(";")[0].strip().lower()
    ext = Path(filename or "").suffix.lower()
    is_valid_type = ct in _ALLOWED_IMAGE_TYPES or ct.startswith("image/")
    is_valid_ext = ct in ("", "application/octet-stream") and ext in _ALLOWED_IMAGE_EXTENSIONS
    if not (is_valid_type or is_valid_ext):
        raise AppException(
            400,
            "VALIDATION_ERROR",
            "Format file harus berupa gambar (JPEG/PNG/WebP)",
        )


async def predict_scan_image(
    contents: bytes,
    filename: str = "scan.jpg",
    content_type: str = "",
) -> dict[str, Any]:
    """Validate uploaded image, run TFLite prediction, and map to disease SOP."""
    _validate_image_upload(contents, filename, content_type)

    try:
        prediction = await predict_image_bytes_async(contents)
    except UnidentifiedImageError as exc:
        raise AppException(
            400, "VALIDATION_ERROR", "File gambar tidak valid atau rusak"
        ) from exc
    except RuntimeError as exc:
        raise AppException(503, "MODEL_UNAVAILABLE", str(exc)) from exc

    disease: dict[str, Any] | None = None
    db_steps: list[dict[str, Any]] = []
    try:
        disease = await diseases_repo.find_by_ml_label(prediction.label)
        if disease:
            db_steps = await scan_steps_repo.get_disease_steps(str(disease["id"]))
    except Exception as exc:
        logger.warning(
            "Disease lookup failed for label=%s, using fallback metadata: %s",
            prediction.label,
            exc,
        )

    fallback_key = _FALLBACK_LABEL_ALIASES.get(
        prediction.label.lower(), prediction.label.lower()
    )
    fallback = _FALLBACK_DISEASE_METADATA.get(fallback_key, {})
    is_healthy = (
        bool(disease.get("is_healthy"))
        if disease
        else bool(fallback.get("is_healthy", False))
    )
    severity = (
        "healthy"
        if is_healthy
        else (
            (disease.get("default_severity") if disease else None)
            or fallback.get("severity")
            or "treatable"
        )
    )

    raw_steps = db_steps if db_steps else fallback.get("steps", [])
    steps = [
        {
            "step_order": int(step.get("step_order") or idx),
            "title": str(step.get("title") or ""),
            "description": str(step.get("description") or ""),
        }
        for idx, step in enumerate(raw_steps, start=1)
    ]

    return {
        "ml_label": prediction.label,
        "disease_id": str(disease["id"]) if disease else None,
        "diagnosis_name": (
            (disease.get("name") if disease else None)
            or fallback.get("name")
            or prediction.label
        ),
        "scientific_name": (
            (disease.get("scientific_name") if disease else None)
            or fallback.get("scientific_name")
        ),
        "description": (
            (disease.get("description") if disease else None)
            or fallback.get("description")
        ),
        "confidence": prediction.confidence,
        "probabilities": prediction.probabilities,
        "severity": severity,
        "infection_location": (
            (disease.get("location_hint") if disease else None)
            or fallback.get("location_hint")
            or "Permukaan Baglog"
        ),
        "model_version": prediction.model_version,
        "steps": steps,
    }


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
    items = await scans_repo.list_scans(
        user_id=user_id,
        status=status,
        rak_id=rak_id,
        disease_id=disease_id,
        limit=limit,
        cursor=cursor,
    )
    scan_ids = [str(item["id"]) for item in items if item.get("id")]
    steps_map = await scan_steps_repo.get_steps_for_scan_ids(scan_ids)
    for item in items:
        item["steps"] = steps_map.get(str(item.get("id")), [])
    return items


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

