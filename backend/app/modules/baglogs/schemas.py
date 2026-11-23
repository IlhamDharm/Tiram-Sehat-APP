"""Baglog schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field


class CreateBaglogRequest(BaseModel):
    code: str | None = None
    batch_id: str | None = None
    rak_id: str
    column_no: int = Field(..., ge=1)
    status: str = "sehat"


class UpdateBaglogStatusRequest(BaseModel):
    status: str


class BaglogOut(BaseModel):
    id: str
    code: str | None = None
    batch_id: str | None = None
    rak_id: str
    column_no: int
    status: str
    planted_at: str | None = None
    harvested_at: str | None = None
    created_at: str
    updated_at: str

