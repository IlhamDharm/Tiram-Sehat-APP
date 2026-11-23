"""Disease router."""
from __future__ import annotations

from fastapi import APIRouter
from app.core.exceptions import AppException, success_response
from app.modules.diseases import repository
from app.modules.scans.steps_repository import get_disease_steps

router = APIRouter()


@router.get("")
async def list_diseases():
    """List all master diseases."""
    diseases = await repository.list_all_active()
    return success_response(diseases)


@router.get("/{disease_id}")
async def get_disease(disease_id: str):
    """Get disease details with guidance steps."""
    disease = await repository.find_by_id(disease_id)
    if not disease:
        raise AppException(404, "NOT_FOUND", "Penyakit tidak ditemukan")
    steps = await get_disease_steps(disease_id)
    disease["steps"] = steps
    return success_response(disease)

