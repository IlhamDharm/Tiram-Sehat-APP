"""Harvest schemas."""
from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, Field


class CreateHarvestRequest(BaseModel):
    batch_id: str | None = None
    kumbung_id: str | None = None
    harvested_at: str
    weight_kg: float = Field(..., gt=0)
    price_per_kg: int = Field(..., ge=0)
    note: str | None = None


class UpdateHarvestRequest(BaseModel):
    harvested_at: str | None = None
    weight_kg: float | None = Field(None, gt=0)
    price_per_kg: int | None = Field(None, ge=0)
    note: str | None = None


class HarvestOut(BaseModel):
    id: str
    user_id: str
    batch_id: str | None = None
    kumbung_id: str | None = None
    harvested_at: str
    weight_kg: float
    price_per_kg: int
    gross_income: int
    note: str | None = None
    created_at: str
    updated_at: str

